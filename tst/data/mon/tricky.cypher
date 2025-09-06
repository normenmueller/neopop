// --- Constraints ---
CREATE CONSTRAINT unique_person_id IF NOT EXISTS
  FOR (p:Person)
  REQUIRE p.id IS UNIQUE;

// --- Multi-line statement ---
MERGE (p1:Person {id:1,
  name:"Alice"})
  -[:LIVES_IN]->(c1:City {name:"Berlin"});

// --- Statement with // comment at the end ---
MERGE (p2:Person {id:2, name:"Bob"}); // Ignore comment

/* --- Multi-line block comment ---
   This comment may be ignored
*/
MERGE (p3:Person {id:3, name:"Charlie"});

// --- Strings containing ; ---
MERGE (n:Note {text:"This is not a statement; it's inside a string"});

// --- Semicolon directly before newline ---
MERGE (p4:Person {id:4, name:"Dana"});
MERGE (p5:Person {id:5, name:"Eve"});

// --- Multi-line property map ---
MERGE (p6:Person {
  id:6,
  name:"Frank"
});

// --- Last statement without extra blank line ---
MERGE (p7:Person {id:7, name:"Grace"});

