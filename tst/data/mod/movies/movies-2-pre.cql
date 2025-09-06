// Created via APOC statement after executing the Neo4j Movie Graph tutorial

CREATE CONSTRAINT movie_title FOR (node:Movie) REQUIRE (node.title) IS UNIQUE;
CREATE CONSTRAINT person_name FOR (node:Person) REQUIRE (node.name) IS UNIQUE;

