#!/usr/bin/env bash
# Read-only PR snapshot for pair-review. Never comments, reviews, or mutates.
set -euo pipefail

IDENTITY=0
PR_INPUT=""

usage() {
  echo "Usage: collect-pr-context.sh [--identity] <PR number or URL>" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity) IDENTITY=1; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) PR_INPUT="$1"; shift; break ;;
  esac
done
if [[ $# -gt 0 && -z "$PR_INPUT" ]]; then
  PR_INPUT="$1"
fi
if [[ -z "$PR_INPUT" ]]; then
  usage
fi

export PAIR_REVIEW_IDENTITY="$IDENTITY"
export PAIR_REVIEW_PR_INPUT="$PR_INPUT"

exec python3 - << 'PY'
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

IDENTITY = os.environ.get("PAIR_REVIEW_IDENTITY") == "1"
PR_INPUT = os.environ["PAIR_REVIEW_PR_INPUT"]
MAX_PAGES = 50
PAGE = 100
THREAD_PAGE = 50
COMMENT_PAGE = 50


def die(msg, code=1):
    print(msg, file=sys.stderr)
    sys.exit(code)


def run(cmd, input_text=None, ok_codes=(0,)):
    r = subprocess.run(
        cmd,
        input=input_text,
        capture_output=True,
        text=True,
    )
    if r.returncode not in ok_codes:
        err = (r.stderr or r.stdout or "").strip()
        raise RuntimeError(err or f"command failed: {cmd}")
    return r


def gh_api(path):
    r = run(["gh", "api", path])
    return json.loads(r.stdout)


def graphql(query, variables):
    payload = json.dumps({"query": query, "variables": variables})
    r = run(["gh", "api", "graphql", "--input", "-"], input_text=payload)
    data = json.loads(r.stdout)
    errors = data.get("errors")
    if errors:
        raise RuntimeError(json.dumps(errors, ensure_ascii=False))
    return data["data"]


def current_repo():
    r = run(["gh", "repo", "view", "--json", "nameWithOwner"])
    nwo = json.loads(r.stdout)["nameWithOwner"]
    owner, name = nwo.split("/", 1)
    return owner, name


def parse_pr(text):
    text = text.strip()
    m = re.search(r"github\.com/([^/]+)/([^/]+)/pull/(\d+)", text)
    if m:
        return m.group(1), m.group(2), int(m.group(3))
    m = re.search(r"/pull/(\d+)", text)
    if m:
        owner, name = current_repo()
        return owner, name, int(m.group(1))
    if re.fullmatch(r"\d+", text):
        owner, name = current_repo()
        return owner, name, int(text)
    die("PR 番号または GitHub PR URL が必要です", 2)


def snapshot_from_rest(owner, name, number):
    pr = gh_api(f"repos/{owner}/{name}/pulls/{number}")
    return {
        "repo": pr["base"]["repo"]["full_name"],
        "number": pr["number"],
        "base_sha": pr["base"]["sha"],
        "head_sha": pr["head"]["sha"],
        "collected_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }, pr


incomplete = []


def mark_incomplete(connection, message, **extra):
    item = {"connection": connection, "message": message}
    item.update(extra)
    incomplete.append(item)


def paginate(query, variables, pick, connection_name):
    nodes = []
    cursor = None
    for page in range(MAX_PAGES):
        vars_ = dict(variables)
        vars_["cursor"] = cursor
        data = graphql(query, vars_)
        conn = pick(data)
        nodes.extend(conn.get("nodes") or [])
        info = conn.get("pageInfo") or {}
        if not info.get("hasNextPage"):
            return nodes
        cursor = info.get("endCursor")
        if not cursor:
            mark_incomplete(connection_name, "hasNextPage but no endCursor")
            return nodes
    else:
        mark_incomplete(
            connection_name,
            f"stopped after {MAX_PAGES} pages; hasNextPage still true",
        )
        return nodes


OWNER, NAME, NUMBER = parse_pr(PR_INPUT)

try:
    snapshot, rest_pr = snapshot_from_rest(OWNER, NAME, NUMBER)
except Exception as e:
    die(f"failed to load PR identity: {e}")

if IDENTITY:
    json.dump({"snapshot": snapshot}, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    sys.exit(0)

PR_Q = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      title
      body
      url
      author { login }
      baseRefName
      headRefName
      baseRefOid
      headRefOid
      isDraft
      state
      reviewDecision
      additions
      deletions
      changedFiles
      createdAt
      updatedAt
    }
  }
}
"""

COMMITS_Q = """
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      commits(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes { commit { oid messageHeadline committedDate } }
      }
    }
  }
}
"""

FILES_Q = """
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      files(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes { path additions deletions changeType }
      }
    }
  }
}
"""

ISSUE_COMMENTS_Q = """
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      comments(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes { databaseId author { login } body createdAt url }
      }
    }
  }
}
"""

REVIEWS_Q = """
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviews(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes { databaseId author { login } state body submittedAt url }
      }
    }
  }
}
"""

THREADS_Q = """
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first: 50) {
            pageInfo { hasNextPage endCursor }
            nodes {
              databaseId
              author { login }
              body
              createdAt
              url
              commit { oid }
            }
          }
        }
      }
    }
  }
}
"""

THREAD_COMMENTS_Q = """
query($id: ID!, $cursor: String) {
  node(id: $id) {
    ... on PullRequestReviewThread {
      comments(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          databaseId
          author { login }
          body
          createdAt
          url
          commit { oid }
        }
      }
    }
  }
}
"""

base_vars = {"owner": OWNER, "name": NAME, "number": NUMBER}

try:
    gql_pr = graphql(PR_Q, base_vars)["repository"]["pullRequest"]
except Exception as e:
    mark_incomplete("pr", str(e))
    gql_pr = None

try:
    commit_nodes = paginate(
        COMMITS_Q,
        base_vars,
        lambda d: d["repository"]["pullRequest"]["commits"],
        "commits",
    )
except Exception as e:
    mark_incomplete("commits", str(e))
    commit_nodes = []

try:
    file_nodes = paginate(
        FILES_Q,
        base_vars,
        lambda d: d["repository"]["pullRequest"]["files"],
        "files",
    )
except Exception as e:
    mark_incomplete("files", str(e))
    file_nodes = []

try:
    issue_comment_nodes = paginate(
        ISSUE_COMMENTS_Q,
        base_vars,
        lambda d: d["repository"]["pullRequest"]["comments"],
        "issue_comments",
    )
except Exception as e:
    mark_incomplete("issue_comments", str(e))
    issue_comment_nodes = []

try:
    review_nodes = paginate(
        REVIEWS_Q,
        base_vars,
        lambda d: d["repository"]["pullRequest"]["reviews"],
        "reviews",
    )
except Exception as e:
    mark_incomplete("reviews", str(e))
    review_nodes = []


def paginate_threads():
    threads = []
    cursor = None
    for page in range(MAX_PAGES):
        data = graphql(THREADS_Q, {**base_vars, "cursor": cursor})
        conn = data["repository"]["pullRequest"]["reviewThreads"]
        for node in conn.get("nodes") or []:
            threads.append(complete_thread_comments(node))
        info = conn.get("pageInfo") or {}
        if not info.get("hasNextPage"):
            return threads
        cursor = info.get("endCursor")
        if not cursor:
            mark_incomplete("reviewThreads", "hasNextPage but no endCursor")
            return threads
    mark_incomplete(
        "reviewThreads",
        f"stopped after {MAX_PAGES} pages; hasNextPage still true",
    )
    return threads


def complete_thread_comments(thread):
    comments_conn = thread.get("comments") or {}
    comments = list(comments_conn.get("nodes") or [])
    info = comments_conn.get("pageInfo") or {}
    cursor = info.get("endCursor")
    pages = 0
    while info.get("hasNextPage"):
        if not cursor:
            mark_incomplete(
                "reviewThreads.comments",
                "hasNextPage but no endCursor",
                thread_id=thread.get("id"),
            )
            break
        pages += 1
        if pages > MAX_PAGES:
            mark_incomplete(
                "reviewThreads.comments",
                f"stopped after {MAX_PAGES} pages; hasNextPage still true",
                thread_id=thread.get("id"),
            )
            break
        try:
            data = graphql(
                THREAD_COMMENTS_Q,
                {"id": thread["id"], "cursor": cursor},
            )
        except Exception as e:
            mark_incomplete(
                "reviewThreads.comments",
                str(e),
                thread_id=thread.get("id"),
            )
            break
        node = data.get("node") or {}
        comments_conn = node.get("comments") or {}
        comments.extend(comments_conn.get("nodes") or [])
        info = comments_conn.get("pageInfo") or {}
        cursor = info.get("endCursor")
    out = {
        "id": thread.get("id"),
        "is_resolved": thread.get("isResolved"),
        "is_outdated": thread.get("isOutdated"),
        "path": thread.get("path"),
        "line": thread.get("line"),
        "original_line": thread.get("originalLine"),
        "comments": [shape_comment(c) for c in comments],
    }
    return out


def login(obj):
    if not obj:
        return None
    author = obj.get("author") if "author" in obj else obj
    if not author:
        return None
    return author.get("login")


def shape_comment(c):
    commit = c.get("commit") or {}
    return {
        "id": c.get("databaseId"),
        "author": login(c),
        "body": c.get("body"),
        "created_at": c.get("createdAt"),
        "url": c.get("url"),
        "commit_oid": commit.get("oid"),
    }


try:
    review_threads = paginate_threads()
except Exception as e:
    mark_incomplete("reviewThreads", str(e))
    review_threads = []

checks = []
try:
    nwo = snapshot["repo"]
    r = run(
        [
            "gh",
            "pr",
            "checks",
            str(NUMBER),
            "--repo",
            nwo,
            "--json",
            "name,state,bucket,link,startedAt,completedAt,description,workflow",
        ],
        ok_codes=(0, 1, 8),
    )
    if r.stdout.strip():
        checks = json.loads(r.stdout)
except Exception as e:
    mark_incomplete("checks", str(e))

pr_out = {
    "title": rest_pr.get("title"),
    "body": rest_pr.get("body"),
    "url": rest_pr.get("html_url"),
    "author": (rest_pr.get("user") or {}).get("login"),
    "base_ref": rest_pr.get("base", {}).get("ref"),
    "head_ref": rest_pr.get("head", {}).get("ref"),
    "draft": rest_pr.get("draft"),
    "state": rest_pr.get("state"),
    "additions": rest_pr.get("additions"),
    "deletions": rest_pr.get("deletions"),
    "changed_files": rest_pr.get("changed_files"),
    "user": (rest_pr.get("user") or {}).get("login"),
}
if gql_pr:
    pr_out.update(
        {
            "title": gql_pr.get("title") or pr_out["title"],
            "body": gql_pr.get("body") if gql_pr.get("body") is not None else pr_out["body"],
            "url": gql_pr.get("url") or pr_out["url"],
            "author": login(gql_pr) or pr_out["author"],
            "base_ref": gql_pr.get("baseRefName") or pr_out["base_ref"],
            "head_ref": gql_pr.get("headRefName") or pr_out["head_ref"],
            "draft": gql_pr.get("isDraft") if gql_pr.get("isDraft") is not None else pr_out["draft"],
            "state": gql_pr.get("state") or pr_out["state"],
            "review_decision": gql_pr.get("reviewDecision"),
            "additions": gql_pr.get("additions"),
            "deletions": gql_pr.get("deletions"),
            "changed_files": gql_pr.get("changedFiles"),
        }
    )

out = {
    "snapshot": snapshot,
    "incomplete": bool(incomplete),
    "pagination_error": incomplete or None,
    "pr": pr_out,
    "commits": [
        {
            "oid": (n.get("commit") or {}).get("oid"),
            "message": (n.get("commit") or {}).get("messageHeadline"),
            "committed_at": (n.get("commit") or {}).get("committedDate"),
        }
        for n in commit_nodes
    ],
    "files": [
        {
            "path": n.get("path"),
            "additions": n.get("additions"),
            "deletions": n.get("deletions"),
            "change_type": n.get("changeType"),
        }
        for n in file_nodes
    ],
    "issue_comments": [shape_comment(c) for c in issue_comment_nodes],
    "reviews": [
        {
            "id": n.get("databaseId"),
            "author": login(n),
            "state": n.get("state"),
            "body": n.get("body"),
            "submitted_at": n.get("submittedAt"),
            "url": n.get("url"),
        }
        for n in review_nodes
    ],
    "review_threads": review_threads,
    "checks": checks,
}

json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
sys.stdout.write("\n")
if incomplete:
    sys.exit(0)
PY
