---
title: Backlog
---

- [ ] `"$2" =~ ^-` blocks file names with leading `-`
- [ ] Neo4j subquery handling (cf. [cql/subq.md](<etc/cql/subq.md>))
- [ ] Optimize chunk *creation*
    - At the moment (v0.1), chunk creation of eg. `beam.cypher` (18.436 statements; 210MB file size) into packages of `N=500` takes up to 1min for each package.
- [ ] Packaging might be more safe but also slower!?
    - In terms of, "slowly, package by package". So is packaging really worthwhile?
- [ ] Terminology `pure` or `impure`relevant for [pangrm](https://app.todoist.com/app/project/pangrm-6XJc6WJhMh4GfpM2)?

