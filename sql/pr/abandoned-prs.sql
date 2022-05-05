-- Abandoned PRs
WITH
last_comments AS (
  SELECT
    r.pull_number
    , max(r.submitted_at) AS review_submitted_at
    , max(rc.created_at) AS comment_created_at
  FROM
    reviews r
  JOIN
    review_comments rc ON rc.pull_request_review_id = r.id
  GROUP BY 1
)
, last_commits AS (
  SELECT
    pull_number
    , max(committer_date) AS committer_date
  FROM
    pull_commits
  GROUP BY 1
)
, authors AS (
    SELECT
      date_trunc('month', date(c.commit_time AT TIME ZONE 'UTC')) AS month
    , ai.logins
    , COALESCE(m.org, '<untracked>') AS org
    , count(*) AS num_commits
    FROM git.default.commits c
    JOIN memory.default.gh_idents ai ON ai.name = c.author_name OR CONTAINS(ai.extra_names, c.author_name)
    LEFT JOIN members m ON CONTAINS(ai.logins, m.login)
    GROUP BY 1, 2, 3
)
, rolling AS (
    SELECT
    *
    , sum(num_commits) OVER (PARTITION BY logins ORDER BY month ROWS BETWEEN 12 PRECEDING AND CURRENT ROW) AS commits_last_year
    FROM authors
)
SELECT
  p.number
, p.title || ' @' || format('https://github.com/trinodb/trino/pull/%s', p.number) AS title
, day(current_timestamp - commits.committer_date) AS days_since_push
, day(current_timestamp - comments.review_submitted_at) AS days_since_review
, day(current_timestamp - comments.comment_created_at) AS days_since_comment
, COALESCE(a.commits_last_year, 0) AS author_commits_last_year
, COALESCE(a.org, '<unknown>') AS author_org
FROM unique_pulls p
LEFT JOIN last_commits commits ON p.number = commits.pull_number
LEFT JOIN last_comments comments ON p.number = comments.pull_number
LEFT JOIN rolling a ON CONTAINS(a.logins, p.user_login) AND date_trunc('month', p.created_at) = a.month
WHERE p.owner = 'trinodb' AND p.repo = 'trino' AND p.state = 'open' AND NOT p.draft
ORDER BY days_since_push DESC NULLS LAST, days_since_review DESC NULLS LAST, days_since_comment DESC NULLS LAST
LIMIT 20
;
