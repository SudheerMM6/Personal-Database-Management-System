--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

-- Started on 2025-06-29 15:04:55

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 6 (class 2615 OID 28704)
--

CREATE SCHEMA course;


ALTER SCHEMA course OWNER TO postgres;

--
-- TOC entry 8 (class 2615 OID 28708)
--

CREATE SCHEMA finance;

ALTER SCHEMA finance OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 28706)
--

CREATE SCHEMA habits;

ALTER SCHEMA habits OWNER TO postgres;

--
-- TOC entry 9 (class 2615 OID 28709)
--

CREATE SCHEMA todo;

ALTER SCHEMA todo OWNER TO postgres;

--
-- TOC entry 11 (class 2615 OID 28705)
--

CREATE SCHEMA trips;

ALTER SCHEMA trips OWNER TO postgres;

--
-- TOC entry 7 (class 2615 OID 28707)
--

CREATE SCHEMA "user";

ALTER SCHEMA "user" OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 27192)
--

CREATE FUNCTION course.update_course_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_status integer;
    all_completed boolean;
    any_started boolean;
BEGIN
    SELECT COUNT(*) = SUM(CASE WHEN completed_date IS NOT NULL THEN 1 ELSE 0 END)
    INTO all_completed
    FROM course.course_topics
    WHERE course_id = NEW.course_id;

    SELECT COUNT(*) > 0
    INTO any_started
    FROM course.course_topics
    WHERE course_id = NEW.course_id AND completed_date IS NOT NULL;

    IF all_completed THEN
        new_status := 3;
    ELSIF any_started THEN
        new_status := 2;
    ELSE
        new_status := 1;
    END IF;

    IF (SELECT status_id FROM course.courses WHERE course_id = NEW.course_id) != new_status THEN
        UPDATE course.courses
        SET status_id = new_status,
            updated_at = CURRENT_TIMESTAMP
        WHERE course_id = NEW.course_id;
    END IF;

    RETURN NEW;
END;
$$;

ALTER FUNCTION course.update_course_status() OWNER TO postgres;

--
-- TOC entry 5170 (class 0 OID 0)
-- Dependencies: 274
--

COMMENT ON FUNCTION course.update_course_status() IS 'Updates status_id in the courses table based on the completion of topics in course_topics: ''Planned'' (no topics), ''Completed'' (all topics completed), ''In Progress'' (otherwise). Triggered by course_topics_status_trigger after inserting or updating completed_date.';

--
-- TOC entry 262 (class 1255 OID 27770)
--

CREATE FUNCTION finance.check_finance_amount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    is_income boolean;
BEGIN
    SELECT ft.is_income INTO is_income
    FROM finance.finance_categories fc  -- Added finance schema
    JOIN finance.finance_types ft ON fc.type_id = ft.type_id
    WHERE fc.category_id = NEW.category_id;

    IF is_income AND NEW.amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive for income category';
    ELSIF NOT is_income AND NEW.amount >= 0 THEN
        RAISE EXCEPTION 'Amount must be negative for expense category';
    END IF;
    RETURN NEW;
END;
$$;

ALTER FUNCTION finance.check_finance_amount() OWNER TO postgres;

--
-- TOC entry 5171 (class 0 OID 0)
-- Dependencies: 262
--

COMMENT ON FUNCTION finance.check_finance_amount() IS 'Checks the correctness of the amount in the finances table: positive for income (type.name = ''Income''), negative for expenses (type.name = ''Expense''). Triggered by finances_amount_trigger before inserting or updating a record.';

--
-- TOC entry 261 (class 1255 OID 26924)
--

CREATE FUNCTION public.update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.update_updated_at() OWNER TO postgres;

--
-- TOC entry 5172 (class 0 OID 0)
-- Dependencies: 261
--

COMMENT ON FUNCTION public.update_updated_at() IS 'Updates the updated_at field to CURRENT_TIMESTAMP when modifying a record in the users, finances, todos, courses, and other tables. Triggered by updated_at_trigger before updating records.';

--
-- TOC entry 260 (class 1255 OID 26708)
--

CREATE FUNCTION todo.set_completed_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.is_completed = TRUE AND OLD.is_completed = FALSE THEN
        NEW.completed_date = CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$;

ALTER FUNCTION todo.set_completed_date() OWNER TO postgres;

--
-- TOC entry 5173 (class 0 OID 0)
-- Dependencies: 260
--

COMMENT ON FUNCTION todo.set_completed_date() IS 'Sets the completed_date field in the todos table to the current date (CURRENT_DATE) if is_completed changes to TRUE. Triggered by todos_completed_date_trigger before updating a record.';

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 252 (class 1259 OID 27694)
--

CREATE TABLE course.course_statuses (
    status_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE course.course_statuses OWNER TO postgres;

--
-- TOC entry 5174 (class 0 OID 0)
-- Dependencies: 252
--

COMMENT ON TABLE course.course_statuses IS 'Reference table for course statuses (Planned, In Progress, Completed).';

--
-- TOC entry 5175 (class 0 OID 0)
-- Dependencies: 252
--

COMMENT ON COLUMN course.course_statuses.status_id IS 'Unique status identifier';

--
-- TOC entry 5176 (class 0 OID 0)
-- Dependencies: 252
--

COMMENT ON COLUMN course.course_statuses.name IS 'Status name (e.g., Planned, Completed)';

--
-- TOC entry 5177 (class 0 OID 0)
-- Dependencies: 252
--

COMMENT ON COLUMN course.course_statuses.created_at IS 'Date and time the record was created';

--
-- TOC entry 240 (class 1259 OID 26808)
--

CREATE TABLE course.course_topics (
    topic_id integer NOT NULL,
    course_id integer NOT NULL,
    user_id integer NOT NULL,
    title character varying(100) NOT NULL,
    material text,
    grade numeric(5,2),
    completed_date date,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT course_topics_grade_check CHECK (((grade >= (0)::numeric) AND (grade <= (5)::numeric)))
);

ALTER TABLE course.course_topics OWNER TO postgres;

--
-- TOC entry 5178 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON TABLE course.course_topics IS 'Table for storing user course topics';

--
-- TOC entry 5179 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON COLUMN course.course_topics.topic_id IS 'Unique topic identifier (primary key)';

--
-- TOC entry 5180 (class 0 OID 0)
-- Dependencies: 240
--
COMMENT ON COLUMN course.course_topics.course_id IS 'Identifier of the course to which the topic belongs (foreign key)';

--
-- TOC entry 5181 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON COLUMN course.course_topics.user_id IS 'Identifier of the user who owns the topic (foreign key)';

--
-- TOC entry 5182 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON COLUMN course.course_topics.title IS 'Topic title';

--
-- TOC entry 5183 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON COLUMN course.course_topics.material IS 'Topic materials (e.g., lecture text or links)';

--
-- TOC entry 5184 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON COLUMN course.course_topics.grade IS 'Grade for the topic (from 0 to 5)';

--
-- TOC entry 5185 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON COLUMN course.course_topics.completed_date IS 'Date the topic was completed';

--
-- TOC entry 5186 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON COLUMN course.course_topics.created_at IS 'Date and time the topic was created';

--
-- TOC entry 5187 (class 0 OID 0)
-- Dependencies: 240
--

COMMENT ON COLUMN course.course_topics.updated_at IS 'Date and time the topic was last updated';

--
-- TOC entry 238 (class 1259 OID 26793)
--

CREATE TABLE course.courses (
    course_id integer NOT NULL,
    user_id integer NOT NULL,
    title character varying(100) NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    status_id integer NOT NULL
);

ALTER TABLE course.courses OWNER TO postgres;

--
-- TOC entry 5188 (class 0 OID 0)
-- Dependencies: 238
--

COMMENT ON TABLE course.courses IS 'Table for storing user courses';

--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 238
--

COMMENT ON COLUMN course.courses.course_id IS 'Unique course identifier (primary key)';

--
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 238
--

COMMENT ON COLUMN course.courses.user_id IS 'Identifier of the user who owns the course (foreign key)';

--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 238
--

COMMENT ON COLUMN course.courses.title IS 'Course title (unique within the user)';

--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 238
--

COMMENT ON COLUMN course.courses.description IS 'Course description';

--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 238
--

COMMENT ON COLUMN course.courses.created_at IS 'Date and time the course was created';

--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 238
--

COMMENT ON COLUMN course.courses.updated_at IS 'Date and time the course was last updated';

--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 238
--

COMMENT ON COLUMN course.courses.status_id IS 'Identifier of the course status (reference to course_statuses)';

--
-- TOC entry 257 (class 1259 OID 27744)
--

CREATE VIEW course.course_grades AS
 SELECT c.course_id,
    c.user_id,
    c.title,
    c.description,
    cs.name AS status,
    avg(ct.grade) AS final_grade
   FROM ((course.courses c
     LEFT JOIN course.course_topics ct ON ((c.course_id = ct.course_id)))
     JOIN course.course_statuses cs ON ((c.status_id = cs.status_id)))
  GROUP BY c.course_id, c.user_id, c.title, c.description, cs.name;

ALTER VIEW course.course_grades OWNER TO postgres;

--
-- TOC entry 5196 (class 0 OID 0)
-- Dependencies: 257
--

COMMENT ON VIEW course.course_grades IS 'View calculating the average grade (final_grade) for topics in each course from the courses table. Includes course_id, user_id, title, description, and status (from course_statuses). Used for performance analysis.';

--
-- TOC entry 248 (class 1259 OID 26899)
--

CREATE VIEW course.course_progress AS
 SELECT c.course_id,
    c.user_id,
    c.title,
    count(ct.topic_id) AS total_topics,
    count(ct.completed_date) AS completed_topics,
    (((count(ct.completed_date))::double precision / (NULLIF(count(ct.topic_id), 0))::double precision) * (100)::double precision) AS completion_percentage
   FROM (course.courses c
     LEFT JOIN course.course_topics ct ON ((c.course_id = ct.course_id)))
  GROUP BY c.course_id, c.user_id, c.title;

ALTER VIEW course.course_progress OWNER TO postgres;

--
-- TOC entry 5197 (class 0 OID 0)
-- Dependencies: 248
--

COMMENT ON VIEW course.course_progress IS 'View showing course completion progress: total topics (total_topics), completed topics (completed_topics), and completion percentage (completion_percentage). Used to track user progress.';

--
-- TOC entry 239 (class 1259 OID 26807)
--

CREATE SEQUENCE course.course_topics_topic_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE course.course_topics_topic_id_seq OWNER TO postgres;

--
-- TOC entry 5198 (class 0 OID 0)
-- Dependencies: 239
--

ALTER SEQUENCE course.course_topics_topic_id_seq OWNED BY course.course_topics.topic_id;

--
-- TOC entry 5199 (class 0 OID 0)
-- Dependencies: 239
--

COMMENT ON SEQUENCE course.course_topics_topic_id_seq IS 'Sequence for generating unique identifiers (topic_id) in the course_topics table, which stores course topics.';

--
-- TOC entry 237 (class 1259 OID 26792)
--

CREATE SEQUENCE course.courses_course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE course.courses_course_id_seq OWNER TO postgres;

--
-- TOC entry 5200 (class 0 OID 0)
-- Dependencies: 237
--

ALTER SEQUENCE course.courses_course_id_seq OWNED BY course.courses.course_id;

--
-- TOC entry 5201 (class 0 OID 0)
-- Dependencies: 237
--

COMMENT ON SEQUENCE course.courses_course_id_seq IS 'Sequence for generating unique identifiers (course_id) in the courses table, storing user courses.';

--
-- TOC entry 224 (class 1259 OID 26513)
--

CREATE TABLE finance.finance_categories (
    category_id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    type_id integer NOT NULL
);


ALTER TABLE finance.finance_categories OWNER TO postgres;

--
-- TOC entry 5202 (class 0 OID 0)
-- Dependencies: 224
--

COMMENT ON TABLE finance.finance_categories IS 'Table for storing user financial operation categories';


--
-- TOC entry 5203 (class 0 OID 0)
-- Dependencies: 224
--

COMMENT ON COLUMN finance.finance_categories.category_id IS 'Unique category identifier (primary key)';


--
-- TOC entry 5204 (class 0 OID 0)
-- Dependencies: 224
--

COMMENT ON COLUMN finance.finance_categories.user_id IS 'Identifier of the user who owns the category (foreign key)';


--
-- TOC entry 5205 (class 0 OID 0)
-- Dependencies: 224
--

COMMENT ON COLUMN finance.finance_categories.name IS 'Category name (unique within the user)';


--
-- TOC entry 5206 (class 0 OID 0)
-- Dependencies: 224
--

COMMENT ON COLUMN finance.finance_categories.created_at IS 'Date and time the category was created';


--
-- TOC entry 5207 (class 0 OID 0)
-- Dependencies: 224
--

COMMENT ON COLUMN finance.finance_categories.updated_at IS 'Date and time the category was last updated';


--
-- TOC entry 5208 (class 0 OID 0)
-- Dependencies: 224
--

COMMENT ON COLUMN finance.finance_categories.type_id IS 'Identifier of the category type (reference to finance_types)';


--
-- TOC entry 223 (class 1259 OID 26512)
--

CREATE SEQUENCE finance.finance_categories_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE finance.finance_categories_category_id_seq OWNER TO postgres;

--
-- TOC entry 5209 (class 0 OID 0)
-- Dependencies: 223
--

ALTER SEQUENCE finance.finance_categories_category_id_seq OWNED BY finance.finance_categories.category_id;


--
-- TOC entry 5210 (class 0 OID 0)
-- Dependencies: 223
--

COMMENT ON SEQUENCE finance.finance_categories_category_id_seq IS 'Sequence for generating unique identifiers (category_id) in the finance_categories table, which stores user financial operation categories.';


--
-- TOC entry 249 (class 1259 OID 27221)
--

CREATE TABLE finance.finance_types (
    type_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_income boolean DEFAULT false NOT NULL
);


ALTER TABLE finance.finance_types OWNER TO postgres;

--
-- TOC entry 5211 (class 0 OID 0)
-- Dependencies: 249
--

COMMENT ON TABLE finance.finance_types IS 'Reference table for financial operation types (Income, Expense). ';


--
-- TOC entry 5212 (class 0 OID 0)
-- Dependencies: 249
--

COMMENT ON COLUMN finance.finance_types.type_id IS 'Unique type identifier';


--
-- TOC entry 5213 (class 0 OID 0)
-- Dependencies: 249
--

COMMENT ON COLUMN finance.finance_types.name IS 'Type name (e.g., Income, Expense)';


--
-- TOC entry 5214 (class 0 OID 0)
-- Dependencies: 249
--

COMMENT ON COLUMN finance.finance_types.created_at IS 'Date and time the record was created';


--
-- TOC entry 226 (class 1259 OID 26527)
--

CREATE TABLE finance.finances (
    finance_id integer NOT NULL,
    user_id integer NOT NULL,
    category_id integer NOT NULL,
    amount numeric(10,2) NOT NULL,
    transaction_date date NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finances_check_amount CHECK ((amount <> (0)::numeric))
);


ALTER TABLE finance.finances OWNER TO postgres;

--
-- TOC entry 5215 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON TABLE finance.finances IS 'Table for tracking user financial operations';


--
-- TOC entry 5216 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON COLUMN finance.finances.finance_id IS 'Unique financial operation identifier (primary key)';


--
-- TOC entry 5217 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON COLUMN finance.finances.user_id IS 'Identifier of the user who performed the operation (foreign key)';


--
-- TOC entry 5218 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON COLUMN finance.finances.category_id IS 'Identifier of the operation category (foreign key)';


--
-- TOC entry 5219 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON COLUMN finance.finances.amount IS 'Operation amount, positive for income, negative for expenses';


--
-- TOC entry 5220 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON COLUMN finance.finances.transaction_date IS 'Date of the operation';


--
-- TOC entry 5221 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON COLUMN finance.finances.note IS 'Note or comment on the operation';


--
-- TOC entry 5222 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON COLUMN finance.finances.created_at IS 'Date and time the operation record was created';


--
-- TOC entry 5223 (class 0 OID 0)
-- Dependencies: 226
--

COMMENT ON COLUMN finance.finances.updated_at IS 'Date and time the record was last updated';


--
-- TOC entry 225 (class 1259 OID 26526)
--

CREATE SEQUENCE finance.finances_finance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE finance.finances_finance_id_seq OWNER TO postgres;

--
-- TOC entry 5224 (class 0 OID 0)
-- Dependencies: 225
--

ALTER SEQUENCE finance.finances_finance_id_seq OWNED BY finance.finances.finance_id;


--
-- TOC entry 5225 (class 0 OID 0)
-- Dependencies: 225
--

COMMENT ON SEQUENCE finance.finances_finance_id_seq IS 'Sequence for generating unique identifiers (finance_id) in the finances table, which stores user financial operations.';


--
-- TOC entry 259 (class 1259 OID 28710)
--

CREATE VIEW finance.financial_summary AS
 SELECT user_id,
    EXTRACT(year FROM transaction_date) AS year,
    EXTRACT(month FROM transaction_date) AS month,
    sum(
        CASE
            WHEN (amount > (0)::numeric) THEN amount
            ELSE (0)::numeric
        END) AS total_income,
    sum(
        CASE
            WHEN (amount < (0)::numeric) THEN (- amount)
            ELSE (0)::numeric
        END) AS total_expense,
    sum(amount) AS balance
   FROM finance.finances f
  GROUP BY user_id, (EXTRACT(year FROM transaction_date)), (EXTRACT(month FROM transaction_date));


ALTER VIEW finance.financial_summary OWNER TO postgres;

--
-- TOC entry 5226 (class 0 OID 0)
-- Dependencies: 259
--

COMMENT ON VIEW finance.financial_summary IS 'View aggregating income (total_income), expenses (total_expense), and balance (balance) per user by month and year based on the finances table.';


--
-- TOC entry 232 (class 1259 OID 26711)
--

CREATE TABLE habits.habit_categories (
    category_id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE habits.habit_categories OWNER TO postgres;

--
-- TOC entry 5227 (class 0 OID 0)
-- Dependencies: 232
--

COMMENT ON TABLE habits.habit_categories IS 'Table for storing user habit categories';


--
-- TOC entry 5228 (class 0 OID 0)
-- Dependencies: 232
--

COMMENT ON COLUMN habits.habit_categories.category_id IS 'Unique category identifier (primary key)';


--
-- TOC entry 5229 (class 0 OID 0)
-- Dependencies: 232
--

COMMENT ON COLUMN habits.habit_categories.user_id IS 'Identifier of the user who owns the category (foreign key)';


--
-- TOC entry 5230 (class 0 OID 0)
-- Dependencies: 232
--

COMMENT ON COLUMN habits.habit_categories.name IS 'Category name (unique within the user)';


--
-- TOC entry 5231 (class 0 OID 0)
-- Dependencies: 232
--

COMMENT ON COLUMN habits.habit_categories.created_at IS 'Date and time the category was created';


--
-- TOC entry 5232 (class 0 OID 0)
-- Dependencies: 232
--

COMMENT ON COLUMN habits.habit_categories.updated_at IS 'Date and time the category was last updated';


--
-- TOC entry 231 (class 1259 OID 26710)
--

CREATE SEQUENCE habits.habit_categories_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE habits.habit_categories_category_id_seq OWNER TO postgres;

--
-- TOC entry 5233 (class 0 OID 0)
-- Dependencies: 231
--

ALTER SEQUENCE habits.habit_categories_category_id_seq OWNED BY habits.habit_categories.category_id;


--
-- TOC entry 5234 (class 0 OID 0)
-- Dependencies: 231
--

COMMENT ON SEQUENCE habits.habit_categories_category_id_seq IS 'Sequence for generating unique identifiers (category_id) in the habit_categories table, which stores user habit categories.';


--
-- TOC entry 255 (class 1259 OID 27718)
--

CREATE TABLE habits.habit_frequencies (
    frequency_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE habits.habit_frequencies OWNER TO postgres;

--
-- TOC entry 5235 (class 0 OID 0)
-- Dependencies: 255
--

COMMENT ON TABLE habits.habit_frequencies IS 'Reference table for habit frequencies (Daily, Every two days, Weekly, Monthly). ';


--
-- TOC entry 5236 (class 0 OID 0)
-- Dependencies: 255
--

COMMENT ON COLUMN habits.habit_frequencies.frequency_id IS 'Unique frequency identifier';


--
-- TOC entry 5237 (class 0 OID 0)
-- Dependencies: 255
--

COMMENT ON COLUMN habits.habit_frequencies.name IS 'Frequency name (e.g., Daily, Weekly)';


--
-- TOC entry 5238 (class 0 OID 0)
-- Dependencies: 255
--

COMMENT ON COLUMN habits.habit_frequencies.created_at IS 'Date and time the record was created';


--
-- TOC entry 236 (class 1259 OID 26744)
--

CREATE TABLE habits.habit_logs (
    log_id integer NOT NULL,
    habit_id integer NOT NULL,
    log_date date NOT NULL,
    is_completed boolean DEFAULT false,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE habits.habit_logs OWNER TO postgres;

--
-- TOC entry 5239 (class 0 OID 0)
-- Dependencies: 236
--

COMMENT ON TABLE habits.habit_logs IS 'Table for storing habit completion logs';


--
-- TOC entry 5240 (class 0 OID 0)
-- Dependencies: 236
--

COMMENT ON COLUMN habits.habit_logs.log_id IS 'Unique log identifier (primary key)';


--
-- TOC entry 5241 (class 0 OID 0)
-- Dependencies: 236
--

COMMENT ON COLUMN habits.habit_logs.habit_id IS 'Identifier of the habit to which the log belongs (foreign key)';


--
-- TOC entry 5242 (class 0 OID 0)
-- Dependencies: 236
--

COMMENT ON COLUMN habits.habit_logs.log_date IS 'Date of the habit log';


--
-- TOC entry 5243 (class 0 OID 0)
-- Dependencies: 236
--

COMMENT ON COLUMN habits.habit_logs.is_completed IS 'Flag indicating habit completion on the specified date (true/false)';


--
-- TOC entry 5244 (class 0 OID 0)
-- Dependencies: 236
--

COMMENT ON COLUMN habits.habit_logs.note IS 'Note or comment on the log';


--
-- TOC entry 5245 (class 0 OID 0)
-- Dependencies: 236
--

COMMENT ON COLUMN habits.habit_logs.created_at IS 'Date and time the log was created';


--
-- TOC entry 5246 (class 0 OID 0)
-- Dependencies: 236
--

COMMENT ON COLUMN habits.habit_logs.updated_at IS 'Date and time the log was last updated';


--
-- TOC entry 235 (class 1259 OID 26743)
--

CREATE SEQUENCE habits.habit_logs_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE habits.habit_logs_log_id_seq OWNER TO postgres;

--
-- TOC entry 5247 (class 0 OID 0)
-- Dependencies: 235
--

ALTER SEQUENCE habits.habit_logs_log_id_seq OWNED BY habits.habit_logs.log_id;


--
-- TOC entry 5248 (class 0 OID 0)
-- Dependencies: 235
--

COMMENT ON SEQUENCE habits.habit_logs_log_id_seq IS 'Sequence for generating unique identifiers (log_id) in the habit_logs table, which stores habit completion records.';


--
-- TOC entry 234 (class 1259 OID 26726)
--

CREATE TABLE habits.habits (
    habit_id integer NOT NULL,
    user_id integer NOT NULL,
    category_id integer NOT NULL,
    name character varying(100) NOT NULL,
    start_date date NOT NULL,
    end_date date,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    frequency_id integer NOT NULL,
    CONSTRAINT habits_check CHECK ((start_date <= end_date))
);


ALTER TABLE habits.habits OWNER TO postgres;

--
-- TOC entry 5249 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON TABLE habits.habits IS 'Table for storing user habits';


--
-- TOC entry 5250 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.habit_id IS 'Unique habit identifier (primary key)';


--
-- TOC entry 5251 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.user_id IS 'Identifier of the user who owns the habit (foreign key)';


--
-- TOC entry 5252 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.category_id IS 'Identifier of the habit category (foreign key)';


--
-- TOC entry 5253 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.name IS 'Habit name (unique within the user)';


--
-- TOC entry 5254 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.start_date IS 'Start date of the habit';


--
-- TOC entry 5255 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.end_date IS 'End date of the habit (may be NULL)';


--
-- TOC entry 5256 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.created_at IS 'Date and time the habit was created';


--
-- TOC entry 5257 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.updated_at IS 'Date and time the habit was last updated';


--
-- TOC entry 5258 (class 0 OID 0)
-- Dependencies: 234
--

COMMENT ON COLUMN habits.habits.frequency_id IS 'Identifier of the habit frequency (reference to habit_frequencies)';


--
-- TOC entry 233 (class 1259 OID 26725)
--

CREATE SEQUENCE habits.habits_habit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE habits.habits_habit_id_seq OWNER TO postgres;

--
-- TOC entry 5259 (class 0 OID 0)
-- Dependencies: 233
--

ALTER SEQUENCE habits.habits_habit_id_seq OWNED BY habits.habits.habit_id;


--
-- TOC entry 5260 (class 0 OID 0)
-- Dependencies: 233
--

COMMENT ON SEQUENCE habits.habits_habit_id_seq IS 'Sequence for generating unique identifiers (habit_id) in the habits table, which stores user habits.';


--
-- TOC entry 251 (class 1259 OID 27686)
--

CREATE TABLE todo.task_priorities (
    priority_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE todo.task_priorities OWNER TO postgres;

--
-- TOC entry 5261 (class 0 OID 0)
-- Dependencies: 251
--

COMMENT ON TABLE todo.task_priorities IS 'Reference table for task priorities (Low, Medium, High).';


--
-- TOC entry 5262 (class 0 OID 0)
-- Dependencies: 251
--

COMMENT ON COLUMN todo.task_priorities.priority_id IS 'Unique priority identifier';


--
-- TOC entry 5263 (class 0 OID 0)
-- Dependencies: 251
--

COMMENT ON COLUMN todo.task_priorities.name IS 'Priority name (e.g., Low, Medium)';


--
-- TOC entry 5264 (class 0 OID 0)
-- Dependencies: 251
--

COMMENT ON COLUMN todo.task_priorities.created_at IS 'Date and time the record was created';


--
-- TOC entry 250 (class 1259 OID 27678)
--

CREATE TABLE todo.task_statuses (
    status_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE todo.task_statuses OWNER TO postgres;

--
-- TOC entry 5265 (class 0 OID 0)
-- Dependencies: 250
--

COMMENT ON TABLE todo.task_statuses IS 'Reference table for task statuses (Planned, In Progress, Completed).';


--
-- TOC entry 5266 (class 0 OID 0)
-- Dependencies: 250
--

COMMENT ON COLUMN todo.task_statuses.status_id IS 'Unique status identifier';


--
-- TOC entry 5267 (class 0 OID 0)
-- Dependencies: 250
--

COMMENT ON COLUMN todo.task_statuses.name IS 'Status name (e.g., Planned, In Progress)';


--
-- TOC entry 5268 (class 0 OID 0)
-- Dependencies: 250
--

COMMENT ON COLUMN todo.task_statuses.created_at IS 'Date and time the record was created';


--
-- TOC entry 228 (class 1259 OID 26675)
--

CREATE TABLE todo.todo_categories (
    category_id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE todo.todo_categories OWNER TO postgres;

--
-- TOC entry 5269 (class 0 OID 0)
-- Dependencies: 228
--

COMMENT ON TABLE todo.todo_categories IS 'Table for storing user task categories';


--
-- TOC entry 5270 (class 0 OID 0)
-- Dependencies: 228
--

COMMENT ON COLUMN todo.todo_categories.category_id IS 'Unique category identifier (primary key)';


--
-- TOC entry 5271 (class 0 OID 0)
-- Dependencies: 228
--

COMMENT ON COLUMN todo.todo_categories.user_id IS 'Identifier of the user who owns the category (foreign key)';


--
-- TOC entry 5272 (class 0 OID 0)
-- Dependencies: 228
--

COMMENT ON COLUMN todo.todo_categories.name IS 'Category name (unique within the user)';


--
-- TOC entry 5273 (class 0 OID 0)
-- Dependencies: 228
--

COMMENT ON COLUMN todo.todo_categories.created_at IS 'Date and time the category was created';


--
-- TOC entry 5274 (class 0 OID 0)
-- Dependencies: 228
--

COMMENT ON COLUMN todo.todo_categories.updated_at IS 'Date and time the category was last updated';


--
-- TOC entry 227 (class 1259 OID 26674)
--

CREATE SEQUENCE todo.todo_categories_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE todo.todo_categories_category_id_seq OWNER TO postgres;

--
-- TOC entry 5275 (class 0 OID 0)
-- Dependencies: 227
--

ALTER SEQUENCE todo.todo_categories_category_id_seq OWNED BY todo.todo_categories.category_id;


--
-- TOC entry 5276 (class 0 OID 0)
-- Dependencies: 227
--

COMMENT ON SEQUENCE todo.todo_categories_category_id_seq IS 'Sequence for generating unique identifiers (category_id) in the todo_categories table, which stores user task categories.';


--
-- TOC entry 230 (class 1259 OID 26689)
--

CREATE TABLE todo.todos (
    todo_id integer NOT NULL,
    user_id integer NOT NULL,
    category_id integer,
    task text NOT NULL,
    due_date date,
    is_completed boolean DEFAULT false,
    completed_date date,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    task_priority_id integer NOT NULL
);


ALTER TABLE todo.todos OWNER TO postgres;

--
-- TOC entry 5277 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON TABLE todo.todos IS 'Table for storing user tasks';


--
-- TOC entry 5278 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.todo_id IS 'Unique task identifier (primary key)';


--
-- TOC entry 5279 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.user_id IS 'Identifier of the user who owns the task (foreign key)';


--
-- TOC entry 5280 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.category_id IS 'Identifier of the task category (foreign key, may be NULL)';


--
-- TOC entry 5281 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.task IS 'Task description';


--
-- TOC entry 5282 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.due_date IS 'Task due date (may be NULL)';


--
-- TOC entry 5283 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.is_completed IS 'Task completion flag (true/false)';


--
-- TOC entry 5284 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.completed_date IS 'Task completion date (set by trigger when is_completed=true)';


--
-- TOC entry 5285 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.created_at IS 'Date and time the task was created';


--
-- TOC entry 5286 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.updated_at IS 'Date and time the task was last updated';


--
-- TOC entry 5287 (class 0 OID 0)
-- Dependencies: 230
--

COMMENT ON COLUMN todo.todos.task_priority_id IS 'Identifier of the task priority (reference to task_priorities)';


--
-- TOC entry 229 (class 1259 OID 26688)
--

CREATE SEQUENCE todo.todos_todo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE todo.todos_todo_id_seq OWNER TO postgres;

--
-- TOC entry 5288 (class 0 OID 0)
-- Dependencies: 229
--

ALTER SEQUENCE todo.todos_todo_id_seq OWNED BY todo.todos.todo_id;


--
-- TOC entry 5289 (class 0 OID 0)
-- Dependencies: 229
--

COMMENT ON SEQUENCE todo.todos_todo_id_seq IS 'Sequence for generating unique identifiers (todo_id) in the todos table, which stores user tasks.';


--
-- TOC entry 254 (class 1259 OID 27710)
--

CREATE TABLE trips.expense_categories (
    category_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE trips.expense_categories OWNER TO postgres;

--
-- TOC entry 5290 (class 0 OID 0)
-- Dependencies: 254
--

COMMENT ON TABLE trips.expense_categories IS 'Reference table for trip expense categories (Food, Transport, etc.). ';


--
-- TOC entry 5291 (class 0 OID 0)
-- Dependencies: 254
--

COMMENT ON COLUMN trips.expense_categories.category_id IS 'Unique category identifier';


--
-- TOC entry 5292 (class 0 OID 0)
-- Dependencies: 254
--

COMMENT ON COLUMN trips.expense_categories.name IS 'Category name (e.g., Food, Transport)';


--
-- TOC entry 5293 (class 0 OID 0)
-- Dependencies: 254
--

COMMENT ON COLUMN trips.expense_categories.created_at IS 'Date and time the record was created';


--
-- TOC entry 258 (class 1259 OID 27818)
--

CREATE SEQUENCE trips.expense_categories_category_id_seq
    START WITH 16
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE trips.expense_categories_category_id_seq OWNER TO postgres;

--
-- TOC entry 5294 (class 0 OID 0)
-- Dependencies: 258
--

ALTER SEQUENCE trips.expense_categories_category_id_seq OWNED BY trips.expense_categories.category_id;


--
-- TOC entry 253 (class 1259 OID 27702)
--

CREATE TABLE trips.transportation_types (
    type_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE trips.transportation_types OWNER TO postgres;

--
-- TOC entry 5295 (class 0 OID 0)
-- Dependencies: 253
--

COMMENT ON TABLE trips.transportation_types IS 'Reference table for transportation types (Airplane, Train, Bus, etc.). ';


--
-- TOC entry 5296 (class 0 OID 0)
-- Dependencies: 253
--

COMMENT ON COLUMN trips.transportation_types.type_id IS 'Unique type identifier';


--
-- TOC entry 5297 (class 0 OID 0)
-- Dependencies: 253
--

COMMENT ON COLUMN trips.transportation_types.name IS 'Type name (e.g., Airplane, Train)';


--
-- TOC entry 5298 (class 0 OID 0)
-- Dependencies: 253
--

COMMENT ON COLUMN trips.transportation_types.created_at IS 'Date and time the record was created';


--
-- TOC entry 244 (class 1259 OID 26859)
--

CREATE TABLE trips.trip_routes (
    route_id integer NOT NULL,
    trip_id integer NOT NULL,
    location_order integer NOT NULL,
    location_name character varying(100) NOT NULL,
    distance_km numeric(10,2),
    cost numeric(10,2),
    arrival_date date,
    departure_date date,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    transportation_type_id integer NOT NULL,
    CONSTRAINT trip_routes_check CHECK ((arrival_date <= departure_date)),
    CONSTRAINT trip_routes_cost_check CHECK ((cost >= (0)::numeric)),
    CONSTRAINT trip_routes_date_check CHECK ((arrival_date <= departure_date))
);


ALTER TABLE trips.trip_routes OWNER TO postgres;

--
-- TOC entry 5299 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON TABLE trips.trip_routes IS 'Table for storing trip routes';


--
-- TOC entry 5300 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.route_id IS 'Unique route identifier (primary key)';


--
-- TOC entry 5301 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.trip_id IS 'Identifier of the trip to which the route belongs (foreign key)';


--
-- TOC entry 5302 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.location_order IS 'Location order in the route (unique within the trip)';


--
-- TOC entry 5303 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.location_name IS 'Location name';


--
-- TOC entry 5304 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.distance_km IS 'Distance between route locations in kilometers';


--
-- TOC entry 5305 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.cost IS 'Transportation cost (in user currency)';


--
-- TOC entry 5306 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.arrival_date IS 'Arrival date at the location';


--
-- TOC entry 5307 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.departure_date IS 'Departure date from the location (may be NULL)';


--
-- TOC entry 5308 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.created_at IS 'Date and time the route was created';


--
-- TOC entry 5309 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.updated_at IS 'Date and time the route was last updated';


--
-- TOC entry 5310 (class 0 OID 0)
-- Dependencies: 244
--

COMMENT ON COLUMN trips.trip_routes.transportation_type_id IS 'Identifier of the transportation type (reference to transportation_types)';


--
-- TOC entry 242 (class 1259 OID 26846)
--

CREATE TABLE trips.trips (
    trip_id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying(100) NOT NULL,
    start_date date NOT NULL,
    end_date date,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT trips_check CHECK ((start_date <= end_date))
);


ALTER TABLE trips.trips OWNER TO postgres;

--
-- TOC entry 5311 (class 0 OID 0)
-- Dependencies: 242
--

COMMENT ON TABLE trips.trips IS 'Table for storing user trips';


--
-- TOC entry 5312 (class 0 OID 0)
-- Dependencies: 242
--

COMMENT ON COLUMN trips.trips.trip_id IS 'Unique trip identifier (primary key)';


--
-- TOC entry 5313 (class 0 OID 0)
-- Dependencies: 242
--

COMMENT ON COLUMN trips.trips.user_id IS 'Identifier of the user who owns the trip (foreign key)';


--
-- TOC entry 5314 (class 0 OID 0)
-- Dependencies: 242
--

COMMENT ON COLUMN trips.trips.name IS 'Trip name';


--
-- TOC entry 5315 (class 0 OID 0)
-- Dependencies: 242
--

COMMENT ON COLUMN trips.trips.start_date IS 'Trip start date';


--
-- TOC entry 5316 (class 0 OID 0)
-- Dependencies: 242
--

COMMENT ON COLUMN trips.trips.end_date IS 'Trip end date (may be NULL)';


--
-- TOC entry 5317 (class 0 OID 0)
-- Dependencies: 242
--

COMMENT ON COLUMN trips.trips.created_at IS 'Date and time the trip record was created';


--
-- TOC entry 5318 (class 0 OID 0)
-- Dependencies: 242
--

COMMENT ON COLUMN trips.trips.updated_at IS 'Date and time the record was last updated';


--
-- TOC entry 245 (class 1259 OID 26873)
--

CREATE VIEW trips.trip_costs AS
 SELECT t.trip_id,
    t.user_id,
    t.name,
    t.start_date,
    t.end_date,
    sum(tr.cost) AS total_cost
   FROM (trips.trips t
     LEFT JOIN trips.trip_routes tr ON ((t.trip_id = tr.trip_id)))
  GROUP BY t.trip_id, t.user_id, t.name, t.start_date, t.end_date;


ALTER VIEW trips.trip_costs OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 26880)
--

CREATE TABLE trips.trip_expenses (
    expense_id integer NOT NULL,
    route_id integer NOT NULL,
    amount numeric(10,2) NOT NULL,
    expense_date date NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    expense_category_id integer NOT NULL,
    CONSTRAINT trip_expenses_amount_check CHECK ((amount > (0)::numeric))
);


ALTER TABLE trips.trip_expenses OWNER TO postgres;

--
-- TOC entry 5319 (class 0 OID 0)
-- Dependencies: 247
--

COMMENT ON COLUMN trips.trip_expenses.expense_id IS 'Unique expense identifier (primary key)';


--
-- TOC entry 5320 (class 0 OID 0)
-- Dependencies: 247
--

COMMENT ON COLUMN trips.trip_expenses.route_id IS 'Identifier of the route to which the expense belongs (foreign key)';


--
-- TOC entry 5321 (class 0 OID 0)
-- Dependencies: 247
--

COMMENT ON COLUMN trips.trip_expenses.amount IS 'Expense amount (in user currency)';


--
-- TOC entry 5322 (class 0 OID 0)
-- Dependencies: 247
--

COMMENT ON COLUMN trips.trip_expenses.expense_date IS 'Expense date';


--
-- TOC entry 5323 (class 0 OID 0)
-- Dependencies: 247
--

COMMENT ON COLUMN trips.trip_expenses.note IS 'Note or comment on the expense';


--
-- TOC entry 5324 (class 0 OID 0)
-- Dependencies: 247
--

COMMENT ON COLUMN trips.trip_expenses.created_at IS 'Date and time the expense record was created';


--
-- TOC entry 5325 (class 0 OID 0)
-- Dependencies: 247
--

COMMENT ON COLUMN trips.trip_expenses.updated_at IS 'Date and time the record was last updated';


--
-- TOC entry 5326 (class 0 OID 0)
-- Dependencies: 247
--

COMMENT ON COLUMN trips.trip_expenses.expense_category_id IS 'Identifier of the expense category (reference to expense_categories)';


--
-- TOC entry 246 (class 1259 OID 26879)
--

CREATE SEQUENCE trips.trip_expenses_expense_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE trips.trip_expenses_expense_id_seq OWNER TO postgres;

--
-- TOC entry 5327 (class 0 OID 0)
-- Dependencies: 246
--

ALTER SEQUENCE trips.trip_expenses_expense_id_seq OWNED BY trips.trip_expenses.expense_id;


--
-- TOC entry 5328 (class 0 OID 0)
-- Dependencies: 246
--

COMMENT ON SEQUENCE trips.trip_expenses_expense_id_seq IS 'Sequence for generating unique identifiers (expense_id) in the trip_expenses table, which stores route trip expenses.';


--
-- TOC entry 243 (class 1259 OID 26858)
--

CREATE SEQUENCE trips.trip_routes_route_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE trips.trip_routes_route_id_seq OWNER TO postgres;

--
-- TOC entry 5329 (class 0 OID 0)
-- Dependencies: 243
--

ALTER SEQUENCE trips.trip_routes_route_id_seq OWNED BY trips.trip_routes.route_id;


--
-- TOC entry 5330 (class 0 OID 0)
-- Dependencies: 243
--

COMMENT ON SEQUENCE trips.trip_routes_route_id_seq IS 'Sequence for generating unique identifiers (route_id) in the trip_routes table, which stores stages of trip routes.';


--
-- TOC entry 241 (class 1259 OID 26845)
--

CREATE SEQUENCE trips.trips_trip_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE trips.trips_trip_id_seq OWNER TO postgres;

--
-- TOC entry 5331 (class 0 OID 0)
-- Dependencies: 241
--

ALTER SEQUENCE trips.trips_trip_id_seq OWNED BY trips.trips.trip_id;


--
-- TOC entry 5332 (class 0 OID 0)
-- Dependencies: 241
--

COMMENT ON SEQUENCE trips.trips_trip_id_seq IS 'Sequence for generating unique identifiers (trip_id) in the trips table, which stores user trip information.';


--
-- TOC entry 256 (class 1259 OID 27726)
--

CREATE TABLE "user".user_roles (
    role_id integer NOT NULL,
    name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "user".user_roles OWNER TO postgres;

--
-- TOC entry 5333 (class 0 OID 0)
-- Dependencies: 256
--

COMMENT ON TABLE "user".user_roles IS 'Reference table for user roles';


--
-- TOC entry 5334 (class 0 OID 0)
-- Dependencies: 256
--

COMMENT ON COLUMN "user".user_roles.role_id IS 'Unique role identifier';


--
-- TOC entry 5335 (class 0 OID 0)
-- Dependencies: 256
--

COMMENT ON COLUMN "user".user_roles.name IS 'Role name (e.g., Administrator, User)';


--
-- TOC entry 5336 (class 0 OID 0)
-- Dependencies: 256
--

COMMENT ON COLUMN "user".user_roles.created_at IS 'Date and time the record was created';


--
-- TOC entry 222 (class 1259 OID 26496)
--

CREATE TABLE "user".users (
    user_id integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    first_name character varying(50),
    last_name character varying(50),
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    role_id integer NOT NULL,
    CONSTRAINT users_email_check CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))
);


ALTER TABLE "user".users OWNER TO postgres;

--
-- TOC entry 5337 (class 0 OID 0)
-- Dependencies: 222
--

COMMENT ON TABLE "user".users IS 'Table for storing system user information';


--
-- TOC entry 5338 (class 0 OID 0)
-- Dependencies: 222
--

COMMENT ON COLUMN "user".users.user_id IS 'Unique user identifier (primary key)';


--
-- TOC entry 5339 (class 0 OID 0)
-- Dependencies: 222
--

COMMENT ON COLUMN "user".users.username IS 'Unique username (no duplicates allowed)';


--
-- TOC entry 5340 (class 0 OID 0)
-- Dependencies: 222
--

COMMENT ON COLUMN "user".users.email IS 'User email (unique; format validated by regex)';


--
-- TOC entry 5341 (class 0 OID 0)
-- Dependencies: 222
--

COMMENT ON COLUMN "user".users.first_name IS 'User first name';


--
-- TOC entry 5342 (class 0 OID 0)
-- Dependencies: 222
--

COMMENT ON COLUMN "user".users.last_name IS 'User last name';


--
-- TOC entry 5343 (class 0 OID 0)
-- Dependencies: 222
--

COMMENT ON COLUMN "user".users.updated_at IS 'Date and time the record was last updated';


--
-- TOC entry 5344 (class 0 OID 0)
-- Dependencies: 222
--

COMMENT ON COLUMN "user".users.role_id IS 'Identifier of the user role (reference to user_roles)';


--
-- TOC entry 221 (class 1259 OID 26495)
--

CREATE SEQUENCE "user".users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "user".users_user_id_seq OWNER TO postgres;

--
-- TOC entry 5345 (class 0 OID 0)
-- Dependencies: 221
--

ALTER SEQUENCE "user".users_user_id_seq OWNED BY "user".users.user_id;


--
-- TOC entry 5346 (class 0 OID 0)
-- Dependencies: 221
--

COMMENT ON SEQUENCE "user".users_user_id_seq IS 'Sequence for generating unique identifiers (user_id) in the users table, which stores system user information.';


--
-- TOC entry 4835 (class 2604 OID 26811)
--

ALTER TABLE ONLY course.course_topics ALTER COLUMN topic_id SET DEFAULT nextval('course.course_topics_topic_id_seq'::regclass);


--
-- TOC entry 4832 (class 2604 OID 26796)
--

ALTER TABLE ONLY course.courses ALTER COLUMN course_id SET DEFAULT nextval('course.courses_course_id_seq'::regclass);


--
-- TOC entry 4809 (class 2604 OID 26516)
--

ALTER TABLE ONLY finance.finance_categories ALTER COLUMN category_id SET DEFAULT nextval('finance.finance_categories_category_id_seq'::regclass);


--
-- TOC entry 4812 (class 2604 OID 26530)
--

ALTER TABLE ONLY finance.finances ALTER COLUMN finance_id SET DEFAULT nextval('finance.finances_finance_id_seq'::regclass);


--
-- TOC entry 4822 (class 2604 OID 26714)
--

ALTER TABLE ONLY habits.habit_categories ALTER COLUMN category_id SET DEFAULT nextval('habits.habit_categories_category_id_seq'::regclass);


--
-- TOC entry 4828 (class 2604 OID 26747)
--

ALTER TABLE ONLY habits.habit_logs ALTER COLUMN log_id SET DEFAULT nextval('habits.habit_logs_log_id_seq'::regclass);


--
-- TOC entry 4825 (class 2604 OID 26729)
--

ALTER TABLE ONLY habits.habits ALTER COLUMN habit_id SET DEFAULT nextval('habits.habits_habit_id_seq'::regclass);


--
-- TOC entry 4815 (class 2604 OID 26678)
--

ALTER TABLE ONLY todo.todo_categories ALTER COLUMN category_id SET DEFAULT nextval('todo.todo_categories_category_id_seq'::regclass);


--
-- TOC entry 4818 (class 2604 OID 26692)
--

ALTER TABLE ONLY todo.todos ALTER COLUMN todo_id SET DEFAULT nextval('todo.todos_todo_id_seq'::regclass);


--
-- TOC entry 4853 (class 2604 OID 27819)
--

ALTER TABLE ONLY trips.expense_categories ALTER COLUMN category_id SET DEFAULT nextval('trips.expense_categories_category_id_seq'::regclass);


--
-- TOC entry 4844 (class 2604 OID 26883)
--

ALTER TABLE ONLY trips.trip_expenses ALTER COLUMN expense_id SET DEFAULT nextval('trips.trip_expenses_expense_id_seq'::regclass);


--
-- TOC entry 4841 (class 2604 OID 26862)
--

ALTER TABLE ONLY trips.trip_routes ALTER COLUMN route_id SET DEFAULT nextval('trips.trip_routes_route_id_seq'::regclass);


--
-- TOC entry 4838 (class 2604 OID 26849)
--

ALTER TABLE ONLY trips.trips ALTER COLUMN trip_id SET DEFAULT nextval('trips.trips_trip_id_seq'::regclass);


--
-- TOC entry 4807 (class 2604 OID 26499)
--

ALTER TABLE ONLY "user".users ALTER COLUMN user_id SET DEFAULT nextval('"user".users_user_id_seq'::regclass);


--
-- TOC entry 5159 (class 0 OID 27694)
-- Dependencies: 252
-- Data for Name: course_statuses; Type: TABLE DATA; Schema: course; Owner: postgres
--



--
-- TOC entry 5149 (class 0 OID 26808)
-- Dependencies: 240
-- Data for Name: course_topics; Type: TABLE DATA; Schema: course; Owner: postgres
--



--
-- TOC entry 5147 (class 0 OID 26793)
-- Dependencies: 238
-- Data for Name: courses; Type: TABLE DATA; Schema: course; Owner: postgres
--



--
-- TOC entry 5133 (class 0 OID 26513)
-- Dependencies: 224
-- Data for Name: finance_categories; Type: TABLE DATA; Schema: finance; Owner: postgres
--

--
-- TOC entry 5156 (class 0 OID 27221)
-- Dependencies: 249
-- Data for Name: finance_types; Type: TABLE DATA; Schema: finance; Owner: postgres
--



--
-- TOC entry 5135 (class 0 OID 26527)
-- Dependencies: 226
-- Data for Name: finances; Type: TABLE DATA; Schema: finance; Owner: postgres
--



--
-- TOC entry 5141 (class 0 OID 26711)
-- Dependencies: 232
-- Data for Name: habit_categories; Type: TABLE DATA; Schema: habits; Owner: postgres
--




--
-- TOC entry 5162 (class 0 OID 27718)
-- Dependencies: 255
-- Data for Name: habit_frequencies; Type: TABLE DATA; Schema: habits; Owner: postgres
--



--
-- TOC entry 5145 (class 0 OID 26744)
-- Dependencies: 236
-- Data for Name: habit_logs; Type: TABLE DATA; Schema: habits; Owner: postgres
--

--
-- TOC entry 5163 (class 0 OID 27726)
-- Dependencies: 256
-- Data for Name: user_roles; Type: TABLE DATA; Schema: user; Owner: postgres
--



--
-- TOC entry 5131 (class 0 OID 26496)
-- Dependencies: 222
-- Data for Name: users; Type: TABLE DATA; Schema: user; Owner: postgres
--


--
-- TOC entry 5347 (class 0 OID 0)
-- Dependencies: 239
--

ALTER TABLE ONLY course.course_statuses
    ADD CONSTRAINT course_statuses_pkey PRIMARY KEY (status_id);


--
-- TOC entry 4913 (class 2606 OID 26816)
--

ALTER TABLE ONLY course.course_topics
    ADD CONSTRAINT course_topics_pkey PRIMARY KEY (topic_id);


--
-- TOC entry 4908 (class 2606 OID 26801)
--

ALTER TABLE ONLY course.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (course_id);


--
-- TOC entry 4910 (class 2606 OID 26921)
--

ALTER TABLE ONLY course.courses
    ADD CONSTRAINT courses_unique UNIQUE (user_id, title);


--
-- TOC entry 4874 (class 2606 OID 26518)
--

ALTER TABLE ONLY finance.finance_categories
    ADD CONSTRAINT finance_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4929 (class 2606 OID 27226)
--

ALTER TABLE ONLY finance.finance_types
    ADD CONSTRAINT finance_types_pkey PRIMARY KEY (type_id);


--
-- TOC entry 4876 (class 2606 OID 26535)
--

ALTER TABLE ONLY finance.finances
    ADD CONSTRAINT finances_pkey PRIMARY KEY (finance_id);


--
-- TOC entry 4891 (class 2606 OID 26716)
--

ALTER TABLE ONLY habits.habit_categories
    ADD CONSTRAINT habit_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4893 (class 2606 OID 26718)
--

ALTER TABLE ONLY habits.habit_categories
    ADD CONSTRAINT habit_categories_unique UNIQUE (user_id, name);


--
-- TOC entry 4941 (class 2606 OID 27723)
--

ALTER TABLE ONLY habits.habit_frequencies
    ADD CONSTRAINT habit_frequencies_pkey PRIMARY KEY (frequency_id);


--
-- TOC entry 4901 (class 2606 OID 26752)
--

ALTER TABLE ONLY habits.habit_logs
    ADD CONSTRAINT habit_logs_pkey PRIMARY KEY (log_id);


--
-- TOC entry 4896 (class 2606 OID 26732)
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT habits_pkey PRIMARY KEY (habit_id);


--
-- TOC entry 4898 (class 2606 OID 26923)
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT habits_unique UNIQUE (user_id, name);


--
-- TOC entry 4906 (class 2606 OID 26754)
--

ALTER TABLE ONLY habits.habit_logs
    ADD CONSTRAINT unique_habit_log UNIQUE (habit_id, log_date);


--
-- TOC entry 4933 (class 2606 OID 27691)
--

ALTER TABLE ONLY todo.task_priorities
    ADD CONSTRAINT task_priorities_pkey PRIMARY KEY (priority_id);


--
-- TOC entry 4931 (class 2606 OID 27683)
--

ALTER TABLE ONLY todo.task_statuses
    ADD CONSTRAINT task_statuses_pkey PRIMARY KEY (status_id);


--
-- TOC entry 4881 (class 2606 OID 26680)
--

ALTER TABLE ONLY todo.todo_categories
    ADD CONSTRAINT todo_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4887 (class 2606 OID 26697)
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT todos_pkey PRIMARY KEY (todo_id);


--
-- TOC entry 4889 (class 2606 OID 27782)
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT todos_unique UNIQUE (user_id, category_id, task);


--
-- TOC entry 4939 (class 2606 OID 27715)
--

ALTER TABLE ONLY trips.expense_categories
    ADD CONSTRAINT expense_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4937 (class 2606 OID 27707)
--

ALTER TABLE ONLY trips.transportation_types
    ADD CONSTRAINT transportation_types_pkey PRIMARY KEY (type_id);


--
-- TOC entry 4927 (class 2606 OID 26887)
--

ALTER TABLE ONLY trips.trip_expenses
    ADD CONSTRAINT trip_expenses_pkey PRIMARY KEY (expense_id);


--
-- TOC entry 4922 (class 2606 OID 26865)
--

ALTER TABLE ONLY trips.trip_routes
    ADD CONSTRAINT trip_routes_pkey PRIMARY KEY (route_id);


--
-- TOC entry 4919 (class 2606 OID 26852)
--

ALTER TABLE ONLY trips.trips
    ADD CONSTRAINT trips_pkey PRIMARY KEY (trip_id);


--
-- TOC entry 4924 (class 2606 OID 26867)
--

ALTER TABLE ONLY trips.trip_routes
    ADD CONSTRAINT unique_route_order UNIQUE (trip_id, location_order);


--
-- TOC entry 4943 (class 2606 OID 27731)
--

ALTER TABLE ONLY "user".user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (role_id);


--
-- TOC entry 4868 (class 2606 OID 26510)
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- TOC entry 4870 (class 2606 OID 26506)
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4872 (class 2606 OID 26508)
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT users_username_unique UNIQUE (username);


--
-- TOC entry 4914 (class 1259 OID 27774)
--

CREATE INDEX idx_course_topics_completed_date ON course.course_topics USING btree (completed_date);


--
-- TOC entry 4915 (class 1259 OID 26898)
--

CREATE INDEX idx_course_topics_course_id ON course.course_topics USING btree (course_id);


--
-- TOC entry 4916 (class 1259 OID 27822)
--

CREATE INDEX idx_course_topics_grade ON course.course_topics USING btree (grade);


--
-- TOC entry 4911 (class 1259 OID 26917)
--

CREATE INDEX idx_courses_user_id ON course.courses USING btree (user_id);


--
-- TOC entry 4877 (class 1259 OID 26894)
--

CREATE INDEX idx_finances_transaction_date ON finance.finances USING btree (transaction_date);


--
-- TOC entry 4878 (class 1259 OID 26893)
--

CREATE INDEX idx_finances_user_id ON finance.finances USING btree (user_id);


--
-- TOC entry 4894 (class 1259 OID 26981)
--

CREATE INDEX idx_habit_categories_user_id ON habits.habit_categories USING btree (user_id);


--
-- TOC entry 4902 (class 1259 OID 26897)
--

CREATE INDEX idx_habit_logs_habit_id ON habits.habit_logs USING btree (habit_id);


--
-- TOC entry 4903 (class 1259 OID 27780)
--

CREATE INDEX idx_habit_logs_is_completed ON habits.habit_logs USING btree (is_completed);


--
-- TOC entry 4904 (class 1259 OID 26919)
--

CREATE INDEX idx_habit_logs_log_date ON habits.habit_logs USING btree (log_date);


--
-- TOC entry 4899 (class 1259 OID 26918)
--

CREATE INDEX idx_habits_user_id ON habits.habits USING btree (user_id);


--
-- TOC entry 4879 (class 1259 OID 26980)
--

CREATE INDEX idx_todo_categories_user_id ON todo.todo_categories USING btree (user_id);


--
-- TOC entry 4882 (class 1259 OID 27773)
--

CREATE INDEX idx_todos_completed_date ON todo.todos USING btree (completed_date);


--
-- TOC entry 4883 (class 1259 OID 26896)
--

CREATE INDEX idx_todos_due_date ON todo.todos USING btree (due_date);


--
-- TOC entry 4884 (class 1259 OID 27772)
--

CREATE INDEX idx_todos_is_completed ON todo.todos USING btree (is_completed);


--
-- TOC entry 4885 (class 1259 OID 26895)
--

CREATE INDEX idx_todos_user_id ON todo.todos USING btree (user_id);


--
-- TOC entry 4925 (class 1259 OID 26916)
--

CREATE INDEX idx_trip_expenses_route_id ON trips.trip_expenses USING btree (route_id);


--
-- TOC entry 4920 (class 1259 OID 26915)
--

CREATE INDEX idx_trip_routes_trip_id ON trips.trip_routes USING btree (trip_id);


--
-- TOC entry 4917 (class 1259 OID 26979)
--

CREATE INDEX idx_trips_user_id ON trips.trips USING btree (user_id);


--
-- TOC entry 4866 (class 1259 OID 26977)
--

CREATE INDEX idx_users_user_id ON "user".users USING btree (user_id);


--
-- TOC entry 4978 (class 2620 OID 28730)
--

CREATE TRIGGER course_topics_status_trigger AFTER INSERT OR UPDATE OF completed_date ON course.course_topics FOR EACH ROW EXECUTE FUNCTION course.update_course_status();


--
-- TOC entry 4979 (class 2620 OID 26957)
--

CREATE TRIGGER course_topics_updated_at_trigger BEFORE UPDATE ON course.course_topics FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4977 (class 2620 OID 26954)
--

CREATE TRIGGER courses_updated_at_trigger BEFORE UPDATE ON course.courses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4968 (class 2620 OID 26930)
--

CREATE TRIGGER finance_categories_updated_at_trigger BEFORE UPDATE ON finance.finance_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4969 (class 2620 OID 27771)
--

CREATE TRIGGER finances_amount_trigger BEFORE INSERT OR UPDATE ON finance.finances FOR EACH ROW EXECUTE FUNCTION finance.check_finance_amount();


--
-- TOC entry 4970 (class 2620 OID 26933)
--

CREATE TRIGGER finances_updated_at_trigger BEFORE UPDATE ON finance.finances FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4974 (class 2620 OID 26945)
--

CREATE TRIGGER habit_categories_updated_at_trigger BEFORE UPDATE ON habits.habit_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4976 (class 2620 OID 26951)
--

CREATE TRIGGER habit_logs_updated_at_trigger BEFORE UPDATE ON habits.habit_logs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4975 (class 2620 OID 26948)
--

CREATE TRIGGER habits_updated_at_trigger BEFORE UPDATE ON habits.habits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4971 (class 2620 OID 26939)
--

CREATE TRIGGER todo_categories_updated_at_trigger BEFORE UPDATE ON todo.todo_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4972 (class 2620 OID 26709)
--

CREATE TRIGGER todos_completed_date_trigger BEFORE UPDATE ON todo.todos FOR EACH ROW EXECUTE FUNCTION todo.set_completed_date();


--
-- TOC entry 4973 (class 2620 OID 26942)
--

CREATE TRIGGER todos_updated_at_trigger BEFORE UPDATE ON todo.todos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4982 (class 2620 OID 26966)
--

CREATE TRIGGER trip_expenses_updated_at_trigger BEFORE UPDATE ON trips.trip_expenses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4981 (class 2620 OID 26963)
--

CREATE TRIGGER trip_routes_updated_at_trigger BEFORE UPDATE ON trips.trip_routes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4980 (class 2620 OID 26960)
--

CREATE TRIGGER trips_updated_at_trigger BEFORE UPDATE ON trips.trips FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4967 (class 2620 OID 26927)
--

CREATE TRIGGER users_updated_at_trigger BEFORE UPDATE ON "user".users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4960 (class 2606 OID 27059)
--

ALTER TABLE ONLY course.course_topics
    ADD CONSTRAINT course_topics_course_id_fkey FOREIGN KEY (course_id) REFERENCES course.courses(course_id) ON DELETE CASCADE;


--
-- TOC entry 4961 (class 2606 OID 27054)
--

ALTER TABLE ONLY course.course_topics
    ADD CONSTRAINT course_topics_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4958 (class 2606 OID 27049)
--

ALTER TABLE ONLY course.courses
    ADD CONSTRAINT courses_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4959 (class 2606 OID 27739)
--

ALTER TABLE ONLY course.courses
    ADD CONSTRAINT fk_courses_status FOREIGN KEY (status_id) REFERENCES course.course_statuses(status_id);


--
-- TOC entry 4945 (class 2606 OID 26994)
--

ALTER TABLE ONLY finance.finance_categories
    ADD CONSTRAINT finance_categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4947 (class 2606 OID 27004)
--

ALTER TABLE ONLY finance.finances
    ADD CONSTRAINT finances_category_id_fkey FOREIGN KEY (category_id) REFERENCES finance.finance_categories(category_id) ON DELETE CASCADE;


--
-- TOC entry 4948 (class 2606 OID 26999)
--

ALTER TABLE ONLY finance.finances
    ADD CONSTRAINT finances_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4946 (class 2606 OID 27229)
--

ALTER TABLE ONLY finance.finance_categories
    ADD CONSTRAINT fk_finance_categories_type FOREIGN KEY (type_id) REFERENCES finance.finance_types(type_id);


--
-- TOC entry 4954 (class 2606 OID 27759)
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT fk_habits_frequency FOREIGN KEY (frequency_id) REFERENCES habits.habit_frequencies(frequency_id);


--
-- TOC entry 4953 (class 2606 OID 27029)
--

ALTER TABLE ONLY habits.habit_categories
    ADD CONSTRAINT habit_categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4957 (class 2606 OID 27044)
--

ALTER TABLE ONLY habits.habit_logs
    ADD CONSTRAINT habit_logs_habit_id_fkey FOREIGN KEY (habit_id) REFERENCES habits.habits(habit_id) ON DELETE CASCADE;


--
-- TOC entry 4955 (class 2606 OID 27039)
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT habits_category_id_fkey FOREIGN KEY (category_id) REFERENCES habits.habit_categories(category_id) ON DELETE CASCADE;


--
-- TOC entry 4956 (class 2606 OID 27034)
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT habits_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4950 (class 2606 OID 27734)
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT fk_todos_task_priority FOREIGN KEY (task_priority_id) REFERENCES todo.task_priorities(priority_id);


--
-- TOC entry 4949 (class 2606 OID 27014)
--

ALTER TABLE ONLY todo.todo_categories
    ADD CONSTRAINT todo_categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4951 (class 2606 OID 27024)
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT todos_category_id_fkey FOREIGN KEY (category_id) REFERENCES todo.todo_categories(category_id) ON DELETE CASCADE;


--
-- TOC entry 4952 (class 2606 OID 27019)
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT todos_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4965 (class 2606 OID 27754)
--

ALTER TABLE ONLY trips.trip_expenses
    ADD CONSTRAINT fk_trip_expenses_category FOREIGN KEY (expense_category_id) REFERENCES trips.expense_categories(category_id);


--
-- TOC entry 4963 (class 2606 OID 27749)
--

ALTER TABLE ONLY trips.trip_routes
    ADD CONSTRAINT fk_trip_routes_transportation_type FOREIGN KEY (transportation_type_id) REFERENCES trips.transportation_types(type_id);


--
-- TOC entry 4966 (class 2606 OID 27074)
--

ALTER TABLE ONLY trips.trip_expenses
    ADD CONSTRAINT trip_expenses_route_id_fkey FOREIGN KEY (route_id) REFERENCES trips.trip_routes(route_id) ON DELETE CASCADE;


--
-- TOC entry 4964 (class 2606 OID 27069)
--

ALTER TABLE ONLY trips.trip_routes
    ADD CONSTRAINT trip_routes_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES trips.trips(trip_id) ON DELETE CASCADE;


--
-- TOC entry 4962 (class 2606 OID 27064)
--

ALTER TABLE ONLY trips.trips
    ADD CONSTRAINT trips_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4944 (class 2606 OID 27765)
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES "user".user_roles(role_id);


-- Completed on 2025-06-29 15:04:56

--
-- PostgreSQL database dump complete
--
