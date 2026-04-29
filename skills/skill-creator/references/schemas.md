\# JSON Schemas



This document defines the JSON schemas used by skill-creator.



\---



\## evals.json



Defines the evals for a skill. Located at `evalsevals.json` within the skill directory.



```json

{

&#x20; skill\_name example-skill,

&#x20; evals \[

&#x20;   {

&#x20;     id 1,

&#x20;     prompt User's example prompt,

&#x20;     expected\_output Description of expected result,

&#x20;     files \[evalsfilessample1.pdf],

&#x20;     expectations \[

&#x20;       The output includes X,

&#x20;       The skill used script Y

&#x20;     ]

&#x20;   }

&#x20; ]

}

```



Fields

\- `skill\_name` Name matching the skill's frontmatter

\- `evals\[].id` Unique integer identifier

\- `evals\[].prompt` The task to execute

\- `evals\[].expected\_output` Human-readable description of success

\- `evals\[].files` Optional list of input file paths (relative to skill root)

\- `evals\[].expectations` List of verifiable statements



\---



\## history.json



Tracks version progression in Improve mode. Located at workspace root.



```json

{

&#x20; started\_at 2026-01-15T103000Z,

&#x20; skill\_name pdf,

&#x20; current\_best v2,

&#x20; iterations \[

&#x20;   {

&#x20;     version v0,

&#x20;     parent null,

&#x20;     expectation\_pass\_rate 0.65,

&#x20;     grading\_result baseline,

&#x20;     is\_current\_best false

&#x20;   },

&#x20;   {

&#x20;     version v1,

&#x20;     parent v0,

&#x20;     expectation\_pass\_rate 0.75,

&#x20;     grading\_result won,

&#x20;     is\_current\_best false

&#x20;   },

&#x20;   {

&#x20;     version v2,

&#x20;     parent v1,

&#x20;     expectation\_pass\_rate 0.85,

&#x20;     grading\_result won,

&#x20;     is\_current\_best true

&#x20;   }

&#x20; ]

}

```



Fields

\- `started\_at` ISO timestamp of when improvement started

\- `skill\_name` Name of the skill being improved

\- `current\_best` Version identifier of the best performer

\- `iterations\[].version` Version identifier (v0, v1, ...)

\- `iterations\[].parent` Parent version this was derived from

\- `iterations\[].expectation\_pass\_rate` Pass rate from grading

\- `iterations\[].grading\_result` baseline, won, lost, or tie

\- `iterations\[].is\_current\_best` Whether this is the current best version



\---



\## grading.json



Output from the grader agent. Located at `run-dirgrading.json`.



```json

{

&#x20; expectations \[

&#x20;   {

&#x20;     text The output includes the name 'John Smith',

&#x20;     passed true,

&#x20;     evidence Found in transcript Step 3 'Extracted names John Smith, Sarah Johnson'

&#x20;   },

&#x20;   {

&#x20;     text The spreadsheet has a SUM formula in cell B10,

&#x20;     passed false,

&#x20;     evidence No spreadsheet was created. The output was a text file.

&#x20;   }

&#x20; ],

&#x20; summary {

&#x20;   passed 2,

&#x20;   failed 1,

&#x20;   total 3,

&#x20;   pass\_rate 0.67

&#x20; },

&#x20; execution\_metrics {

&#x20;   tool\_calls {

&#x20;     Read 5,

&#x20;     Write 2,

&#x20;     Bash 8

&#x20;   },

&#x20;   total\_tool\_calls 15,

&#x20;   total\_steps 6,

&#x20;   errors\_encountered 0,

&#x20;   output\_chars 12450,

&#x20;   transcript\_chars 3200

&#x20; },

&#x20; timing {

&#x20;   executor\_duration\_seconds 165.0,

&#x20;   grader\_duration\_seconds 26.0,

&#x20;   total\_duration\_seconds 191.0

&#x20; },

&#x20; claims \[

&#x20;   {

&#x20;     claim The form has 12 fillable fields,

&#x20;     type factual,

&#x20;     verified true,

&#x20;     evidence Counted 12 fields in field\_info.json

&#x20;   }

&#x20; ],

&#x20; user\_notes\_summary {

&#x20;   uncertainties \[Used 2023 data, may be stale],

&#x20;   needs\_review \[],

&#x20;   workarounds \[Fell back to text overlay for non-fillable fields]

&#x20; },

&#x20; eval\_feedback {

&#x20;   suggestions \[

&#x20;     {

&#x20;       assertion The output includes the name 'John Smith',

&#x20;       reason A hallucinated document that mentions the name would also pass

&#x20;     }

&#x20;   ],

&#x20;   overall Assertions check presence but not correctness.

&#x20; }

}

```



Fields

\- `expectations\[]` Graded expectations with evidence

\- `summary` Aggregate passfail counts

\- `execution\_metrics` Tool usage and output size (from executor's metrics.json)

\- `timing` Wall clock timing (from timing.json)

\- `claims` Extracted and verified claims from the output

\- `user\_notes\_summary` Issues flagged by the executor

\- `eval\_feedback` (optional) Improvement suggestions for the evals, only present when the grader identifies issues worth raising



\---



\## metrics.json



Output from the executor agent. Located at `run-diroutputsmetrics.json`.



```json

{

&#x20; tool\_calls {

&#x20;   Read 5,

&#x20;   Write 2,

&#x20;   Bash 8,

&#x20;   Edit 1,

&#x20;   Glob 2,

&#x20;   Grep 0

&#x20; },

&#x20; total\_tool\_calls 18,

&#x20; total\_steps 6,

&#x20; files\_created \[filled\_form.pdf, field\_values.json],

&#x20; errors\_encountered 0,

&#x20; output\_chars 12450,

&#x20; transcript\_chars 3200

}

```



Fields

\- `tool\_calls` Count per tool type

\- `total\_tool\_calls` Sum of all tool calls

\- `total\_steps` Number of major execution steps

\- `files\_created` List of output files created

\- `errors\_encountered` Number of errors during execution

\- `output\_chars` Total character count of output files

\- `transcript\_chars` Character count of transcript



\---



\## timing.json



Wall clock timing for a run. Located at `run-dirtiming.json`.



How to capture When a subagent task completes, the task notification includes `total\_tokens` and `duration\_ms`. Save these immediately — they are not persisted anywhere else and cannot be recovered after the fact.



```json

{

&#x20; total\_tokens 84852,

&#x20; duration\_ms 23332,

&#x20; total\_duration\_seconds 23.3,

&#x20; executor\_start 2026-01-15T103000Z,

&#x20; executor\_end 2026-01-15T103245Z,

&#x20; executor\_duration\_seconds 165.0,

&#x20; grader\_start 2026-01-15T103246Z,

&#x20; grader\_end 2026-01-15T103312Z,

&#x20; grader\_duration\_seconds 26.0

}

```



\---



\## benchmark.json



Output from Benchmark mode. Located at `benchmarkstimestampbenchmark.json`.



```json

{

&#x20; metadata {

&#x20;   skill\_name pdf,

&#x20;   skill\_path pathtopdf,

&#x20;   executor\_model claude-sonnet-4-20250514,

&#x20;   analyzer\_model most-capable-model,

&#x20;   timestamp 2026-01-15T103000Z,

&#x20;   evals\_run \[1, 2, 3],

&#x20;   runs\_per\_configuration 3

&#x20; },



&#x20; runs \[

&#x20;   {

&#x20;     eval\_id 1,

&#x20;     eval\_name Ocean,

&#x20;     configuration with\_skill,

&#x20;     run\_number 1,

&#x20;     result {

&#x20;       pass\_rate 0.85,

&#x20;       passed 6,

&#x20;       failed 1,

&#x20;       total 7,

&#x20;       time\_seconds 42.5,

&#x20;       tokens 3800,

&#x20;       tool\_calls 18,

&#x20;       errors 0

&#x20;     },

&#x20;     expectations \[

&#x20;       {text ..., passed true, evidence ...}

&#x20;     ],

&#x20;     notes \[

&#x20;       Used 2023 data, may be stale,

&#x20;       Fell back to text overlay for non-fillable fields

&#x20;     ]

&#x20;   }

&#x20; ],



&#x20; run\_summary {

&#x20;   with\_skill {

&#x20;     pass\_rate {mean 0.85, stddev 0.05, min 0.80, max 0.90},

&#x20;     time\_seconds {mean 45.0, stddev 12.0, min 32.0, max 58.0},

&#x20;     tokens {mean 3800, stddev 400, min 3200, max 4100}

&#x20;   },

&#x20;   without\_skill {

&#x20;     pass\_rate {mean 0.35, stddev 0.08, min 0.28, max 0.45},

&#x20;     time\_seconds {mean 32.0, stddev 8.0, min 24.0, max 42.0},

&#x20;     tokens {mean 2100, stddev 300, min 1800, max 2500}

&#x20;   },

&#x20;   delta {

&#x20;     pass\_rate +0.50,

&#x20;     time\_seconds +13.0,

&#x20;     tokens +1700

&#x20;   }

&#x20; },



&#x20; notes \[

&#x20;   Assertion 'Output is a PDF file' passes 100% in both configurations - may not differentiate skill value,

&#x20;   Eval 3 shows high variance (50% ± 40%) - may be flaky or model-dependent,

&#x20;   Without-skill runs consistently fail on table extraction expectations,

&#x20;   Skill adds 13s average execution time but improves pass rate by 50%

&#x20; ]

}

```



Fields

\- `metadata` Information about the benchmark run

&#x20; - `skill\_name` Name of the skill

&#x20; - `timestamp` When the benchmark was run

&#x20; - `evals\_run` List of eval names or IDs

&#x20; - `runs\_per\_configuration` Number of runs per config (e.g. 3)

\- `runs\[]` Individual run results

&#x20; - `eval\_id` Numeric eval identifier

&#x20; - `eval\_name` Human-readable eval name (used as section header in the viewer)

&#x20; - `configuration` Must be `with\_skill` or `without\_skill` (the viewer uses this exact string for grouping and color coding)

&#x20; - `run\_number` Integer run number (1, 2, 3...)

&#x20; - `result` Nested object with `pass\_rate`, `passed`, `total`, `time\_seconds`, `tokens`, `errors`

\- `run\_summary` Statistical aggregates per configuration

&#x20; - `with\_skill`  `without\_skill` Each contains `pass\_rate`, `time\_seconds`, `tokens` objects with `mean` and `stddev` fields

&#x20; - `delta` Difference strings like `+0.50`, `+13.0`, `+1700`

\- `notes` Freeform observations from the analyzer



Important The viewer reads these field names exactly. Using `config` instead of `configuration`, or putting `pass\_rate` at the top level of a run instead of nested under `result`, will cause the viewer to show emptyzero values. Always reference this schema when generating benchmark.json manually.



\---



\## comparison.json



Output from blind comparator. Located at `grading-dircomparison-N.json`.



```json

{

&#x20; winner A,

&#x20; reasoning Output A provides a complete solution with proper formatting and all required fields. Output B is missing the date field and has formatting inconsistencies.,

&#x20; rubric {

&#x20;   A {

&#x20;     content {

&#x20;       correctness 5,

&#x20;       completeness 5,

&#x20;       accuracy 4

&#x20;     },

&#x20;     structure {

&#x20;       organization 4,

&#x20;       formatting 5,

&#x20;       usability 4

&#x20;     },

&#x20;     content\_score 4.7,

&#x20;     structure\_score 4.3,

&#x20;     overall\_score 9.0

&#x20;   },

&#x20;   B {

&#x20;     content {

&#x20;       correctness 3,

&#x20;       completeness 2,

&#x20;       accuracy 3

&#x20;     },

&#x20;     structure {

&#x20;       organization 3,

&#x20;       formatting 2,

&#x20;       usability 3

&#x20;     },

&#x20;     content\_score 2.7,

&#x20;     structure\_score 2.7,

&#x20;     overall\_score 5.4

&#x20;   }

&#x20; },

&#x20; output\_quality {

&#x20;   A {

&#x20;     score 9,

&#x20;     strengths \[Complete solution, Well-formatted, All fields present],

&#x20;     weaknesses \[Minor style inconsistency in header]

&#x20;   },

&#x20;   B {

&#x20;     score 5,

&#x20;     strengths \[Readable output, Correct basic structure],

&#x20;     weaknesses \[Missing date field, Formatting inconsistencies, Partial data extraction]

&#x20;   }

&#x20; },

&#x20; expectation\_results {

&#x20;   A {

&#x20;     passed 4,

&#x20;     total 5,

&#x20;     pass\_rate 0.80,

&#x20;     details \[

&#x20;       {text Output includes name, passed true}

&#x20;     ]

&#x20;   },

&#x20;   B {

&#x20;     passed 3,

&#x20;     total 5,

&#x20;     pass\_rate 0.60,

&#x20;     details \[

&#x20;       {text Output includes name, passed true}

&#x20;     ]

&#x20;   }

&#x20; }

}

```



\---



\## analysis.json



Output from post-hoc analyzer. Located at `grading-diranalysis.json`.



```json

{

&#x20; comparison\_summary {

&#x20;   winner A,

&#x20;   winner\_skill pathtowinnerskill,

&#x20;   loser\_skill pathtoloserskill,

&#x20;   comparator\_reasoning Brief summary of why comparator chose winner

&#x20; },

&#x20; winner\_strengths \[

&#x20;   Clear step-by-step instructions for handling multi-page documents,

&#x20;   Included validation script that caught formatting errors

&#x20; ],

&#x20; loser\_weaknesses \[

&#x20;   Vague instruction 'process the document appropriately' led to inconsistent behavior,

&#x20;   No script for validation, agent had to improvise

&#x20; ],

&#x20; instruction\_following {

&#x20;   winner {

&#x20;     score 9,

&#x20;     issues \[Minor skipped optional logging step]

&#x20;   },

&#x20;   loser {

&#x20;     score 6,

&#x20;     issues \[

&#x20;       Did not use the skill's formatting template,

&#x20;       Invented own approach instead of following step 3

&#x20;     ]

&#x20;   }

&#x20; },

&#x20; improvement\_suggestions \[

&#x20;   {

&#x20;     priority high,

&#x20;     category instructions,

&#x20;     suggestion Replace 'process the document appropriately' with explicit steps,

&#x20;     expected\_impact Would eliminate ambiguity that caused inconsistent behavior

&#x20;   }

&#x20; ],

&#x20; transcript\_insights {

&#x20;   winner\_execution\_pattern Read skill - Followed 5-step process - Used validation script,

&#x20;   loser\_execution\_pattern Read skill - Unclear on approach - Tried 3 different methods

&#x20; }

}

```

