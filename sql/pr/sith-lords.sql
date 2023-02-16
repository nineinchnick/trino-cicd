-- Always two, there are. No more. No less. A master and an apprentice
WITH pairs AS (
    SELECT
        c.commit_time AT TIME ZONE 'UTC' AS commit_time
      , ai.name AS ai_name
      , ma.org AS ai_org
      , ci.name AS ci_name
      , mc.org AS ci_org
      , count(*) AS commits_in_pr
    FROM git.default.commits c
    JOIN memory.default.gh_idents ai ON ai.email = c.author_email OR CONTAINS(ai.extra_emails, c.author_email)
    JOIN memory.default.gh_idents ci ON ci.email = c.committer_email OR CONTAINS(ci.extra_emails, c.committer_email)
    LEFT JOIN members ma ON CONTAINS(ai.logins, ma.login)
    LEFT JOIN members mc ON CONTAINS(ci.logins, mc.login)
    WHERE ai.email != ci.email
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    ai_name AS author_name
  --, ai_org AS author_org
  , ci_name AS committer_name
  --, ci_org AS committer_org
  , sum(commits_in_pr) AS commits
  , count(*) AS pull_requests
FROM pairs
GROUP BY ai_name, ci_name
ORDER BY pull_requests DESC, ai_name, ci_name
LIMIT 50
;
