---
component_type: "*"
session_type: "test"
---

Test the happy path first and thoroughly at the top of the file.
Continue to write tests in descending order of likelihood.
Avoid mocks wherever possible. Use real data and implementations.
Use recorders like ex_vcr to record actual system interactions where you can't use real data and implementations.
Mocks are appropriate to use at the boundary of the application, especially when they will heavily impact the performance of the test suite.
Identify application boundaries that need mocks, and write them if necessary.
Tests should be relatively fast. We don't want to slow the test suite down.
Write fixed, concrete assertions. 
Never use case, if or "or" in your test assertions.
Do not use try catch statements in tests.
Use fixtures wherever possible.
Delegate as much setup as possible.
Use ExUnit.CaptureLog to prevent shitting up the logs.