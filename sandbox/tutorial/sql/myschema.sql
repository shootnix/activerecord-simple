 DROP TABLE authors;
 DROP TABLE articles;
 DROP TABLE comments;

CREATE TABLE authors (
    id   INTEGER PRIMARY KEY,
    name TEXT
);

CREATE TABLE articles (
    id        INTEGER PRIMARY KEY,
    title     TEXT NOT NULL,
    content   TEXT NOT NULL,
    author_id INTEGER NOT NULL REFERENCES authors(id)
);

CREATE TABLE comments (
    id              INTEGER PRIMARY KEY,
    create_date     TIMESTAMP NOT NULL DEFAULT NOW,
    comments_author TEXT NOT NULL,
    comment         TEXT,
    article_id      INTEGER NOT NULL REFERENCES articles(id)
);
