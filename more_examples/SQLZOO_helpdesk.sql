"""SQLZOO: Helpdesk Solutions"""


"""EASY QUESTIONS"""

"1. There are three issues that include the words 'index' and 'Oracle'. Find the call_date for each of them."
SELECT call_date, call_ref FROM Issue
WHERE (Detail LIKE '%index%') AND (Detail LIKE '%Oracle%')

"2. Samantha Hall made three calls on 2017-08-14. Show the date and time for each."
SELECT call_date, First_name, Last_name FROM Issue
JOIN Caller ON (Issue.Caller_id=Caller.Caller_id)
WHERE First_name = 'Samantha' AND Last_name = 'Hall'
   AND DATE(call_date) LIKE '%2017-08-14%'

"3. There are 500 calls in the system (roughly). Write a query that shows the number that have each status."
SELECT Status, COUNT(*) AS Volume FROM Issue
GROUP BY Status

"4. Calls are not normally assigned to a manager but it does happen. How many calls have been assigned to staff who are at Manager Level?"
SELECT COUNT(*) AS mlcc FROM Level
RIGHT JOIN Staff ON (Level.Level_code=Staff.Level_code)
RIGHT JOIN Issue ON (Staff.Staff_code=Issue.Assigned_to)   -- bc we want all of the issue calls
WHERE Manager = 'Y'
GROUP BY Manager

"5. Show the manager for each shift. Your output should include the shift date and type; also the first and last name of the manager."
SELECT Shift_date, Shift_type, First_name, Last_name
FROM Shift
LEFT JOIN Staff ON (Shift.Manager=Staff.Staff_code)
ORDER BY Shift_date



"""MEDIUM QUESTIONS"""

"6. List the Company name and the number of calls for those companies with more than 18 calls."
SELECT Company_name, COUNT(*) as cc FROM Customer
JOIN Caller ON (Caller.Company_ref=Customer.Company_ref)
JOIN Issue ON (Issue.Caller_id=Caller.Caller_id)
GROUP BY Company_name
HAVING cc > 18

"7. Find the callers who have never made a call. Show first name and last name."
SELECT First_name, Last_name FROM Caller
LEFT JOIN Issue ON (Issue.Caller_id=Caller.Caller_id)
WHERE Call_date IS NULL

"8. For each customer, show the company name, contact name, and number of calls where the number of calls is fewer than 5."
SELECT Company_name, First_name, Last_name, nc FROM
   (SELECT Company_name, Contact_id, COUNT(*) as nc FROM Customer    -- This table gets Company_name, Contact_id, and nc but still needs to
   JOIN Caller ON (Customer.Company_ref=Caller.Company_ref)          -- switch Contact_id with First_name and Last_name with Caller
   JOIN Issue ON (Issue.Caller_id=Caller.Caller_id)
   GROUP BY Company_name, Contact_id
   HAVING nc < 5) AS x
JOIN Caller ON (Caller.Caller_id=x.Contact_id)

"9. For each shift show the number of staff assigned. Beware that some roles may be NULL and that the same person
might have been assigned to multiple roles (The roles are 'Manager', 'Operator', 'Engineer1', 'Engineer2')."
SELECT Shift_date, Shift_type, COUNT(DISTINCT(Worker)) AS cw
FROM (SELECT Shift_date, Shift_type, Manager as Worker FROM Shift
      UNION
      SELECT Shift_date, Shift_type, Operator FROM Shift
      UNION
      SELECT Shift_date, Shift_type, Engineer1 FROM Shift
      UNION
      SELECT Shift_date, Shift_type, Engineer2 FROM Shift) AS x
GROUP BY Shift_date, Shift_type

"10. Caller 'Harry' claims that the operator who took his most recent call was abusive and insulting.
Find out who took the call (full name) and when."
SELECT First_name, Last_name, Call_date FROM
   (SELECT Call_date, Taken_by FROM Issue
   LEFT JOIN Caller ON (Caller.Caller_id=Issue.Caller_id)
   WHERE First_name = 'Harry'
      AND Call_date = (SELECT MAX(Call_date) FROM Issue
         LEFT JOIN Caller ON (Caller.Caller_id=Issue.Caller_id)
         WHERE First_name = 'Harry')) as x
JOIN Staff ON (Staff.Staff_code=x.Taken_by)



"""HARD QUESTIONS"""

"11. Show the manager and number of calls received for each hour of the day on 2017-08-12."
SELECT Manager,
   (CONCAT(EXTRACT(Year FROM Date), '-', EXTRACT(Month FROM Date), '-', EXTRACT(Day FROM Date), ' ', EXTRACT(Hour FROM Date))) as Hr,
   COUNT(*) as cc
FROM (SELECT Call_date as Date, (CASE                           -- Sectioning hours by Early and Late to join the managers
   WHEN EXTRACT(Hour FROM Call_date) < 14 THEN 'Early'
   ELSE 'Late' END) as Shift_type FROM Issue) as x
JOIN (SELECT Shift_type, Manager FROM Shift                     -- Joining the managers for that specific day and shift type
   WHERE EXTRACT(Month FROM Shift_date) = 8
   AND EXTRACT(Day FROM Shift_date) = 12) as y
   ON (x.Shift_type=y.Shift_type)
WHERE EXTRACT(Month FROM Date) = 8
   AND EXTRACT(Day FROM Date) = 12
GROUP BY Hr
ORDER BY HOUR(Date)


"12. 80/20 rule. It is said that 80% of the calls are generated by 20% of the callers.
Is this true? What percentage of calls are generated by the most active 20% of callers."
-- Who are the most active 20% of callers?
SELECT First_name, Last_name, COUNT(*) as Num_calls FROM Issue
JOIN Caller ON (Caller.Caller_id=Issue.Caller_id)
GROUP BY First_name, Last_name
ORDER BY COUNT(*) DESC

-- How many callers are there in the top 20% of callers?
SELECT COUNT(*) * .20 FROM Caller

-- Caller IDs of the top 20% of those who have made the most calls, where Row_num is their ranks
SELECT X.Caller_id FROM
(SELECT Caller.Caller_id, COUNT(*) as Num_calls,
   ROW_NUMBER() OVER(ORDER BY Num_calls DESC) as Row_num
FROM Issue
JOIN Caller ON (Caller.Caller_id=Issue.Caller_id)
GROUP BY Caller_id) AS X
WHERE X.Row_num <= (SELECT COUNT(*) * .20 FROM Caller)

-- How many calls are made by those included in this list?
SELECT COUNT(*) FROM Issue
WHERE Caller_id IN (SELECT X.Caller_id FROM
   (SELECT Caller.Caller_id, COUNT(*) as Num_calls,
   ROW_NUMBER() OVER(ORDER BY Num_calls DESC) as Row_num
   FROM Issue
   JOIN Caller ON (Caller.Caller_id=Issue.Caller_id)
   GROUP BY Caller_id) AS X
   WHERE X.Row_num <= (SELECT COUNT(*) * .20 FROM Caller))

-- FINAL SOLUTION
SELECT 100 * COUNT(*) / (SELECT COUNT(*) FROM Issue) AS t20pc FROM Issue
WHERE Caller_id IN (SELECT X.Caller_id FROM
   (SELECT Caller.Caller_id, COUNT(*) as Num_calls,
   ROW_NUMBER() OVER(ORDER BY Num_calls DESC) as Row_num
   FROM Issue
   JOIN Caller ON (Caller.Caller_id=Issue.Caller_id)
   GROUP BY Caller_id) AS X
   WHERE X.Row_num <= (SELECT COUNT(*) * .20 FROM Caller))


"13. Customers who call in the last five minutes of a shift are annoying. Find the most active customer who has never been annoying."
-- Get only the calls that aren't within the last 5 mins of a shift (Shifts end at 14:00 and 20:00)
SELECT Caller_id, HOUR(Call_date), MINUTE(Call_date),
  (CASE WHEN (HOUR(Call_date) = 13 AND MINUTE(Call_date) > 54) OR (HOUR(Call_date) = 19 AND MINUTE(Call_date) > 54)
   THEN 1 ELSE 0 END)
FROM Issue
WHERE (CASE WHEN (HOUR(Call_date) = 13 AND MINUTE(Call_date) > 54) OR (HOUR(Call_date) = 19 AND MINUTE(Call_date) > 54)
   THEN 1 ELSE 0 END) = 0

-- Get the one top company that has had the most calls from the table with only non-annoying calls
   -- Looked at the number of calls per Caller_id, then tying those Caller_ids to their Company_id, then summing the counts by company
SELECT Company_ref, SUM(Call_count) as Company_count
FROM (SELECT Caller_id, COUNT(*) as Call_count
     FROM (SELECT Caller_id, HOUR(Call_date), MINUTE(Call_date),
          (CASE WHEN (HOUR(Call_date) = 13 AND MINUTE(Call_date) > 54) OR (HOUR(Call_date) = 19 AND MINUTE(Call_date) > 54)
          THEN 1 ELSE 0 END)
          FROM Issue
          WHERE (CASE WHEN (HOUR(Call_date) = 13 AND MINUTE(Call_date) > 54) OR (HOUR(Call_date) = 19 AND MINUTE(Call_date) > 54)
          THEN 1 ELSE 0 END) = 0) as x
     GROUP BY Caller_id) as y
JOIN Caller ON (y.Caller_id = Caller.Caller_id)
GROUP BY Company_ref
ORDER BY Company_count DESC
LIMIT 1

-- FINAL SOLUTION: Match the Company_ref to the Company_name
SELECT Company_name, Company_count as abna
FROM (SELECT Company_ref, SUM(Call_count) as Company_count
     FROM (SELECT Caller_id, COUNT(*) as Call_count
           FROM (SELECT Caller_id, HOUR(Call_date), MINUTE(Call_date),
                (CASE WHEN (HOUR(Call_date) = 13 AND MINUTE(Call_date) > 54) OR (HOUR(Call_date) = 19 AND MINUTE(Call_date) > 54)
                THEN 1 ELSE 0 END)
                FROM Issue
                WHERE (CASE WHEN (HOUR(Call_date) = 13 AND MINUTE(Call_date) > 54) OR (HOUR(Call_date) = 19 AND MINUTE(Call_date) > 54)
                THEN 1 ELSE 0 END) = 0) as x
           GROUP BY Caller_id) as y
     JOIN Caller ON (y.Caller_id = Caller.Caller_id)
     GROUP BY Company_ref
     ORDER BY Company_count DESC
     LIMIT 1) as z
LEFT JOIN Customer ON (z.Company_ref=Customer.Company_ref)


"14. If every caller registered with a customer makes a call in one day then that
customer has 'maximal usage' of the service. List the maximal customers for 2017-08-13."
-- (1) Counts of people who called for an issue on 2017-08-13 by Company_ref
SELECT Company_ref, COUNT(*) as Issue_count
FROM (SELECT Caller_id, COUNT(*) FROM Issue
      WHERE YEAR(Call_date)=2017 AND MONTH(Call_date)=8 AND DAY(Call_date)=13
      GROUP BY Caller_id) as x
JOIN Caller ON (x.Caller_id=Caller.Caller_id)
GROUP BY Company_ref

-- (2) All companies and their number of registered callers
SELECT y.Company_ref, Company_name, Caller_count FROM Customer
JOIN (SELECT Company_ref, COUNT(*) as Caller_count FROM Caller
GROUP BY Company_ref) as y ON (y.Company_ref=Customer.Company_ref)

-- FINAL SOLUTION
SELECT * FROM (SELECT Company_name, Caller_count, Issue_count
   FROM (SELECT Company_ref, COUNT(*) as Issue_count                                            -- (1)
         FROM (SELECT Caller_id, COUNT(*) FROM Issue
               WHERE YEAR(Call_date)=2017 AND MONTH(Call_date)=8 AND DAY(Call_date)=13
               GROUP BY Caller_id) as x
         JOIN Caller ON (x.Caller_id=Caller.Caller_id)
         GROUP BY Company_ref) as a
         JOIN (SELECT y.Company_ref, Company_name, Caller_count FROM Customer                   -- (2)  [Joined Table 1 and Table 2]
               JOIN (SELECT Company_ref, COUNT(*) as Caller_count FROM Caller
               GROUP BY Company_ref) as y ON (y.Company_ref=Customer.Company_ref)) as b
               ON (a.Company_ref=b.Company_ref)) as c
WHERE Caller_count = Issue_count
ORDER BY Company_name


"15. Consecutive calls occur when an operator deals with two callers within 10 minutes. Find the longest
sequence of consecutive calls – give the name of the operator and the first and last call date in the sequence."
SELECT Taken_by, First_call, Last_call, Call_count as Calls
FROM (SELECT Taken_by, Call_date as Last_call,
      @consecutive_count :=
				CASE WHEN TIMESTAMPDIFF(MINUTE, @call_date, call_date) <= 10 THEN @consecutive_count + 1 ELSE 1 END as call_count,
			@first_call_date :=
        CASE WHEN @consecutive_count = 1 THEN call_date ELSE @first_call_date END as first_call,
			@call_date := Issue.call_date as call_date
		FROM Issue,
			(SELECT @consecutive_count := 0, @call_date := 0, @first_call_date := 0) as row_number_init
		ORDER BY Taken_by, Call_date) as x
ORDER BY Call_count DESC LIMIT 1
