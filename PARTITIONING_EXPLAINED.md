This was combed from instant messaging session Keith had with Aleksandr.

It describes partitioning as it relates to Postges and how Postgres implements partitioning
(from a user's perspective)  using table inheritance.

Keith: do you know what a primary key is?
me: yes
Keith:  ok… do you know what a check constraint is
me:  yes
Keith:  great, do you know what an index is?
me:  yes
Keith:  excellent. Do you know what table inheritance means with respect to postgres?
me:  Do you mean partitioning ?
Keith:
  no, they are two different things, let me explain:
  a very simple table:
    create table a (a1 integer, a2 integer);
  and a child of it:
    create table b () inherits (a);
  that is table inheritance.  table 'b' has all the columns of table 'a'
me:  Yes, it is clear
Keith:
  if you go to a psql prompt you can type those in and see what happens…. but let me explain further,
  you can do something like this:
    create table c (c1 text) inherits a;
  table 'c' has all columns table 'a' has AND it has 'c1' (a text column), cool?
  (look at the difference between the create table 'c' and create table 'b')
me:  b has only columns a1 and a2
Keith:
  correct, that is table inheritance.  no strings between the tables except the schemas are shared.
  well.. there is one string.  child tables will be search for data when the parent table is queried, example:

  psql=# create table a (a1 integer, a2 integer);
  psql=# create table b () inherits (a);
  psql=# create table c (c1 text) inherits (a);
  psql=# insert into c (a1,a2,c1) values (1,2,'three');
  psql=# insert into b (a1,a2) values (11,22);
  psql=# insert into a (a1,a2) values (111,222);
  psql=# select * from a;
  a1       | a2  
  -----+-----
      111 | 222
        11 |   22
          1 |     2
  (3 rows)

  psql=# select * from b;
  a1     | a2
  ----+----
      11 | 22
  (1 row)

  psql=# select * from c;
  a1     | a2    |  c1  
  ----+----+-------
   1      |  2     | three
  (1 row)

  does this make sense?
me:  cool
Keith:  
  notice that you can insert values in the parent table and the child's schema can be different.. no problems.
  pretty slick,eh?  this is table inheritance.  partitioning is built on top of it.
Keith:
  so, postgres can handle large tables.   millions of rows.  but indexes can get really large.
  Especially if you have an index on a text column, but even indexes on integer fields can be large.
  tens of millions of rows ... billions of rows… at some point the indexes take up more space that ready memory allows
  if that happens Postgres partially swaps in indexes as it can... works on them, then swaps in others parts.  This is very slow,
  understand?
me:  yes I do
Keith:
  We'll work with two major tables for the rest of the examples. COMPANIES representing a business and EMPLOYEEES representing
  all known employees for all known COMPANIES.
     create table companies
       (
     id                    serial not null primary key,
     created_at       timestamp not null default now(),
     updated_at      timestamp,
     name               text null
       );
       create table employees
       (
     id                     serial not null primary key,
     created_at        timestamp not null default now(),
     updated_at       timestamp,
     name                text not null,
     salary               money not null,
     company_id      integer not null references companies
       );
  does this make sense?
me:  yes it does
Keith:
  let's say our job is to track every employee for 4 very large companies. one might just put them all in the employees table...
    insert into companies (name) values ('Fluent Mobile, Inc.'),('Fiksu, Inc.'),('AppExchanger.com, Inc.'),('FreeMyApps.com, Inc.');
  four companies -- got it?
me:  i see
Keith: 
  but, let's say that each company has 5 million employees.  that is a large amount of data
  and doing a search on their name field would be slow even with an index on some machines.
  to solve that problem we partition the employees table on "company_id"… and here is how we do that:
    create table employees_1 (check (company_id = 1)) inherits (employees);
    create table employees_2 (check (company_id = 2)) inherits (employees);
    create table employees_3 (check (company_id = 3)) inherits (employees);
    create table employees_4 (check (company_id = 4)) inherits (employees);
  the check constraint is the key to partitioning...
  so, employees_1 inherits from employees (has all its columns) AND it adds one thing — a check constraint which forces any row in
  its table to have a company_id value = 1, make sense?
me:  yes
Keith:
  Then to insert records into the table:
     insert into employees_1 (name, salary, company_id) values ('keith', '100', 1);
   does work, but
     insert into employees_1 (name, salary, company_id) values ('keith', '100', 2);
   will fail
me:  check constraint processed data. it is clear
Keith:
 Exactly.  Great. Now i'll add some data to the tables.
 notice this:
    psql=# \d employees
          Table "public.employees"
      Column           |            Type                                       |                       Modifiers                        
    ------------+-----------------------------+--------------------------------------------------------
    id                      | integer                                               | not null default nextval('employees_id_seq'::regclass)
    created_at         | timestamp without time zone            | not null default now()
    updated_at        | timestamp without time zone            |
    name                 | text                                                    | not null
    salary                | money                                                | not null
    company_id      | integer                                                | not null
    Indexes:
       "employees_pkey" PRIMARY KEY, btree (id)
    Foreign-key constraints:
       "employees_company_id_fkey" FOREIGN KEY (company_id) REFERENCES companies(id)
    Number of child tables: 4 (Use \d+ to list them.)
  see that there are child tables and PSQL tells you about them
me:  i see all childrens
Keith: 
 now for data.
    insert into employees_1 (name, salary, company_id) values ('keith', '100', 1), ('k2', '101', 1),('k3', '105', 1),('k4', '110', 1);
    insert into employees_2 (name, salary, company_id) values ('sally', '100', 2), ('s2', '101', 2),('s3', '105', 2),('s4', '110', 2);
    insert into employees_3 (name, salary, company_id) values ('william', '100', 3), ('w2', '101', 3),('w3', '105', 3),('w4', '110', 3);
    insert into employees_4 (name, salary, company_id) values ('laura', '100', 4), ('l2', '101', 4),('l3', '105', 4),('l4', '110', 4);
  note that we don't insert any data into the parent table… i will explain that soon.
  (you can insert data into the parent table… it's legal.. but not logical for our purposes).
  you can delete all rows in all tables by saying:
    delete from employees;
  but.. insert that data.. and let's talk about query planners.  the query planner is the actuall machine
  in the database that figures out how to execute the query.
  'explain' shows you what the query planner is doing/would do.
  so… we'll use explain to figure out how partitioning helps us, try
    psql=# explain select * from employees where name = 'keith';
               QUERY PLAN                                    
    -----------------------------------------------------------------------------------
    Result  (cost=0.00..103.75 rows=20 width=64)
      ->  Append  (cost=0.00..103.75 rows=20 width=64)
      ->  Seq Scan on employees  (cost=0.00..20.75 rows=4 width=64)
      Filter: (name = 'keith'::text)
      ->  Seq Scan on employees_1 employees  (cost=0.00..20.75 rows=4 width=64)
      Filter: (name = 'keith'::text)
      ->  Seq Scan on employees_2 employees  (cost=0.00..20.75 rows=4 width=64)
      Filter: (name = 'keith'::text)
      ->  Seq Scan on employees_3 employees  (cost=0.00..20.75 rows=4 width=64)
      Filter: (name = 'keith'::text)
      ->  Seq Scan on employees_4 employees  (cost=0.00..20.75 rows=4 width=64)
      Filter: (name = 'keith'::text)
    (12 rows)
  which is the worst of all possibilities. it checks every child table for name 'keith' then consolodates the information and returns the one row.
  but.. if we do this
    explain select * from employees where name = 'keith' and company_id = 1;
  we get
    psql=# explain select * from employees where name = 'keith' and company_id = 1;
               QUERY PLAN                                    
    -----------------------------------------------------------------------------------
    Result  (cost=0.00..45.80 rows=2 width=64)
      ->  Append  (cost=0.00..45.80 rows=2 width=64)
      ->  Seq Scan on employees  (cost=0.00..22.90 rows=1 width=64)
      Filter: ((name = 'keith'::text) AND (company_id = 1))
      ->  Seq Scan on employees_1 employees  (cost=0.00..22.90 rows=1 width=64)
      Filter: ((name = 'keith'::text) AND (company_id = 1))
    (6 rows)
    so much win
me:  cost is better, and plan too
Keith:
  Correct, because the planner could tell (using knowledge from the check constraint) that employees_1 was the only table it needed to look at.
  equally as valid and even faster is:
    explain select * from employees_1 where name = 'keith';
    psql=# explain select * from employees_1 where name = 'keith';
           QUERY PLAN                          
    -------------------------------------------------------------
    Seq Scan on employees_1  (cost=0.00..20.75 rows=4 width=64)
      Filter: (name = 'keith'::text)
    (2 rows)
  you can imaging that an update will work in the same way.  if the company_id is not specified it will check all tables.
me:  i see
Keith:
  great, so… that is partitioning.  there are other forms...  but before we go on,  try this:
    create table employees_5 (check (company_id = 5)) inherits (employees);
    insert into employees_5 (name, salary, company_id) values ('vicky', '100', 5), ('v2', '101', 5),('v3', '105', 5),('v4', '110', 5);
  well, that works, why?  how could we insert a value 5 into company_id if employees has a reference to companies and there is not
  a record with company.id = 5.  Because postgres does not propogate indexes and referential integrity to child tables.
  So, even though employees has the reference, employees_5 does not and the only constraint is that company_id = 5,
  but not if company.id = 5 exists in the companies table does that make sense?
me:  yes it is clear
Keith: so, to alleviate that problem we need to add foreign key constraints to each of the child tables
me:  Yes it can resolve our inconsistency problem
Keith:
    ALTER TABLE employees_1 ADD CONSTRAINT e1cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_2 ADD CONSTRAINT e2cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_3 ADD CONSTRAINT e3cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_4 ADD CONSTRAINT e4cfk FOREIGN KEY (company_id) REFERENCES companies (id);
  so, those should work.. but we need one more for employees_5, but of course:
    psql=# ALTER TABLE employees_5 ADD CONSTRAINT e5cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ERROR:  insert or update on table "employees_5" violates foreign key constraint "e5cfk"
    DETAIL:  Key (company_id)=(5) is not present in table "companies".
  make sense?
me:  yes
Keith:  to fix this we need to add one more row to companies...
Keith:
    INSERT INTO companies (name) values ('gga');
  and now ALTER TABLE employees_5 ADD CONSTRAINT e5cfk FOREIGN KEY (company_id) REFERENCES companies (id);
  works, ok?
me:  ok
Keith:
  so, you can partition in many things… not just company_id = 1
  you could say "check (company_id in (1,2,3))" for one child table
  and "check (company_id = 4)" for another
  and "check (company_id >= 5)" in yet another
  if that made sense, you can even have check constraints overlap (although you shouldn't do that)
  but one table could have CHECK (company_id <= 3)
  and another could have CHECK (company_id >= 3)
  so both child tables would be searched when company_id = 3.  is that a problem?  well.. that is up to you to decide with your data.
  but we will, from now on, deal only with child tables that are mutually exclusive to fully optimize the query planner
  does that make sense?
me:  yes that does
Keith:  Great, you can also partition on created_at… one minute.
Keith:
    drop table employees_1;
    drop table employees_2;
    drop table employees_3;
    drop table employees_4;
    drop table employees_5;
    create table employees_2000 (check (created_at >= '2000-01-01' and created_at < '2001-01-01')) inherits (employees);
    create table employees_2001 (check (created_at >= '2001-01-01' and created_at < '2002-01-01')) inherits (employees);
    create table employees_2002 (check (created_at >= '2002-01-01' and created_at < '2003-01-01')) inherits (employees);
    create table employees_2003 (check (created_at >= '2003-01-01' and created_at < '2004-01-01')) inherits (employees);
    create table employees_2004 (check (created_at >= '2004-01-01' and created_at < '2005-01-01')) inherits (employees);
  is that obvious what it does?
me:  yes, we create partition for each year between 2000-2005 years
Keith:
  yes, and only created_at is looked at to determine where the query planner will look for records
  make sense?  company_id is not in the check constraint so the planner will not use it for queries on these tables
me:  to have the excellent performance we need to add two partition for company_id and created_at
Keith:
  it depends on how we access the data.  but YES you are right
  BUT if we only cared about when the employee record was created and NEVER cared about the company_id… then this schema
  fits our needs, correct?
    select distinct company_id from employees where created_at = '2001-06-14';
  something like that is still efficient, for this schema, right?
  or we can think about a schema of reports.. which we only care about reports on a year by year basis.  
  employees might not be the best example of usage for this… but the logic should be sane.
me:  yes it very helpfull for reporting statistics and we have the best performance
Keith:
  great, now.. let me blow your mind. is your mind ready to be blown?
me:  I'm fine.  yet...
Keith:
    drop table employees_1;
    drop table employees_2;
    drop table employees_3;
    drop table employees_4;
    drop table employees_5;
    drop table employees_2000;
    drop table employees_2001;
    drop table employees_2002;
    drop table employees_2003;
    drop table employees_2004;
    create table employees_1 (check (company_id = 1)) inherits (employees);
    create table employees_2 (check (company_id = 2)) inherits (employees);
    create table employees_3 (check (company_id = 3)) inherits (employees);
    create table employees_4 (check (company_id = 4)) inherits (employees);
    create table employees_5 (check (company_id = 5)) inherits (employees);
    create table employees_1_2000 (check (created_at >= '2000-01-01' and created_at < '2001-01-01')) inherits (employees_1);
    create table employees_1_2001 (check (created_at >= '2001-01-01' and created_at < '2002-01-01')) inherits (employees_1);
    create table employees_1_2002 (check (created_at >= '2002-01-01' and created_at < '2003-01-01')) inherits (employees_1);
    create table employees_1_2003 (check (created_at >= '2003-01-01' and created_at < '2004-01-01')) inherits (employees_1);
    create table employees_1_2004 (check (created_at >= '2004-01-01' and created_at < '2005-01-01')) inherits (employees_1);

    create table employees_2_2000 (check (created_at >= '2000-01-01' and created_at < '2001-01-01')) inherits (employees_2);
    create table employees_2_2001 (check (created_at >= '2001-01-01' and created_at < '2002-01-01')) inherits (employees_2);
    create table employees_2_2002 (check (created_at >= '2002-01-01' and created_at < '2003-01-01')) inherits (employees_2);
    create table employees_2_2003 (check (created_at >= '2003-01-01' and created_at < '2004-01-01')) inherits (employees_2);
    create table employees_2_2004 (check (created_at >= '2004-01-01' and created_at < '2005-01-01')) inherits (employees_2);

    create table employees_3_2000 (check (created_at >= '2000-01-01' and created_at < '2001-01-01')) inherits (employees_3);
    create table employees_3_2001 (check (created_at >= '2001-01-01' and created_at < '2002-01-01')) inherits (employees_3);
    create table employees_3_2002 (check (created_at >= '2002-01-01' and created_at < '2003-01-01')) inherits (employees_3);
    create table employees_3_2003 (check (created_at >= '2003-01-01' and created_at < '2004-01-01')) inherits (employees_3);
    create table employees_3_2004 (check (created_at >= '2004-01-01' and created_at < '2005-01-01')) inherits (employees_3);

    create table employees_4_2000 (check (created_at >= '2000-01-01' and created_at < '2001-01-01')) inherits (employees_4);
    create table employees_4_2001 (check (created_at >= '2001-01-01' and created_at < '2002-01-01')) inherits (employees_4);
    create table employees_4_2002 (check (created_at >= '2002-01-01' and created_at < '2003-01-01')) inherits (employees_4);
    create table employees_4_2003 (check (created_at >= '2003-01-01' and created_at < '2004-01-01')) inherits (employees_4);
    create table employees_4_2004 (check (created_at >= '2004-01-01' and created_at < '2005-01-01')) inherits (employees_4);

    create table employees_5_2000 (check (created_at >= '2000-01-01' and created_at < '2001-01-01')) inherits (employees_5);
    create table employees_5_2001 (check (created_at >= '2001-01-01' and created_at < '2002-01-01')) inherits (employees_5);
    create table employees_5_2002 (check (created_at >= '2002-01-01' and created_at < '2003-01-01')) inherits (employees_5);
    create table employees_5_2003 (check (created_at >= '2003-01-01' and created_at < '2004-01-01')) inherits (employees_5);
    create table employees_5_2004 (check (created_at >= '2004-01-01' and created_at < '2005-01-01')) inherits (employees_5);

  we can have multi level partitioning.  in this case… the first level inherits from employees
  but each employees_X table has 5 children that inherit from it and put the check constraint on created_at.
  so, now a query:
    select * from employees where created_at = '2001-07–4' and company_id = 5;
  wins big.  the referential integrity problem with company_id => companies still exists.  we must apply that
    ALTER TABLE employees_1_2000 ADD CONSTRAINT e1cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_1_2001 ADD CONSTRAINT e2cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_1_2002 ADD CONSTRAINT e3cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_1_2003 ADD CONSTRAINT e4cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_1_2004 ADD CONSTRAINT e5cfk FOREIGN KEY (company_id) REFERENCES companies (id);

    ALTER TABLE employees_2_2000 ADD CONSTRAINT e1cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_2_2001 ADD CONSTRAINT e2cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_2_2002 ADD CONSTRAINT e3cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_2_2003 ADD CONSTRAINT e4cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_2_2004 ADD CONSTRAINT e5cfk FOREIGN KEY (company_id) REFERENCES companies (id);

    ALTER TABLE employees_3_2000 ADD CONSTRAINT e1cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_3_2001 ADD CONSTRAINT e2cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_3_2002 ADD CONSTRAINT e3cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_3_2003 ADD CONSTRAINT e4cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_3_2004 ADD CONSTRAINT e5cfk FOREIGN KEY (company_id) REFERENCES companies (id);

    ALTER TABLE employees_4_2000 ADD CONSTRAINT e1cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_4_2001 ADD CONSTRAINT e2cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_4_2002 ADD CONSTRAINT e3cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_4_2003 ADD CONSTRAINT e4cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_4_2004 ADD CONSTRAINT e5cfk FOREIGN KEY (company_id) REFERENCES companies (id);

    ALTER TABLE employees_5_2000 ADD CONSTRAINT e1cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_5_2001 ADD CONSTRAINT e2cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_5_2002 ADD CONSTRAINT e3cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_5_2003 ADD CONSTRAINT e4cfk FOREIGN KEY (company_id) REFERENCES companies (id);
    ALTER TABLE employees_5_2004 ADD CONSTRAINT e5cfk FOREIGN KEY (company_id) REFERENCES companies (id);

  and that is a multi level partitioned table.  you only stick data in leaf tables.. that is EMPLOYEES_4_2000 gets data.
  EMPLOYEES and EMPLOYEES_4 do not get any data (or you lose some benefit from the query planner)
  so… that is partitioning.
me:  cool!
Keith:
  you now know as much about partitioning as I do. read this sometime:
    http://www.postgresql.org/docs/9.1/interactive/ddl-partitioning.html