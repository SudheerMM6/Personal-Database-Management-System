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
-- Name: course; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA course;


ALTER SCHEMA course OWNER TO postgres;

--
-- TOC entry 8 (class 2615 OID 28708)
-- Name: finance; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA finance;

ALTER SCHEMA finance OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 28706)
-- Name: habits; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA habits;

ALTER SCHEMA habits OWNER TO postgres;

--
-- TOC entry 9 (class 2615 OID 28709)
-- Name: todo; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA todo;

ALTER SCHEMA todo OWNER TO postgres;

--
-- TOC entry 11 (class 2615 OID 28705)
-- Name: trips; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA trips;

ALTER SCHEMA trips OWNER TO postgres;

--
-- TOC entry 7 (class 2615 OID 28707)
-- Name: user; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA "user";

ALTER SCHEMA "user" OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 27192)
-- Name: update_course_status(); Type: FUNCTION; Schema: course; Owner: postgres
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
-- Name: FUNCTION update_course_status(); Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON FUNCTION course.update_course_status() IS 'Updates status_id in the courses table based on the completion of topics in course_topics: ''Planned'' (no topics), ''Completed'' (all topics completed), ''In Progress'' (otherwise). Triggered by course_topics_status_trigger after inserting or updating completed_date.';

--
-- TOC entry 262 (class 1255 OID 27770)
-- Name: check_finance_amount(); Type: FUNCTION; Schema: finance; Owner: postgres
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
-- Name: FUNCTION check_finance_amount(); Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON FUNCTION finance.check_finance_amount() IS 'Checks the correctness of the amount in the finances table: positive for income (type.name = ''Income''), negative for expenses (type.name = ''Expense''). Triggered by finances_amount_trigger before inserting or updating a record.';

--
-- TOC entry 261 (class 1255 OID 26924)
-- Name: update_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
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
-- Name: FUNCTION update_updated_at(); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.update_updated_at() IS 'Updates the updated_at field to CURRENT_TIMESTAMP when modifying a record in the users, finances, todos, courses, and other tables. Triggered by updated_at_trigger before updating records.';

--
-- TOC entry 260 (class 1255 OID 26708)
-- Name: set_completed_date(); Type: FUNCTION; Schema: todo; Owner: postgres
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
-- Name: FUNCTION set_completed_date(); Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON FUNCTION todo.set_completed_date() IS 'Sets the completed_date field in the todos table to the current date (CURRENT_DATE) if is_completed changes to TRUE. Triggered by todos_completed_date_trigger before updating a record.';

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 252 (class 1259 OID 27694)
-- Name: course_statuses; Type: TABLE; Schema: course; Owner: postgres
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
-- Name: TABLE course_statuses; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON TABLE course.course_statuses IS 'Reference table for course statuses (Planned, In Progress, Completed).';

--
-- TOC entry 5175 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN course_statuses.status_id; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_statuses.status_id IS 'Unique status identifier';

--
-- TOC entry 5176 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN course_statuses.name; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_statuses.name IS 'Status name (e.g., Planned, Completed)';

--
-- TOC entry 5177 (class 0 OID 0)
-- Dependencies: 252
-- Name: COLUMN course_statuses.created_at; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_statuses.created_at IS 'Date and time the record was created';

--
-- TOC entry 240 (class 1259 OID 26808)
-- Name: course_topics; Type: TABLE; Schema: course; Owner: postgres
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
-- Name: TABLE course_topics; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON TABLE course.course_topics IS 'Table for storing user course topics';

--
-- TOC entry 5179 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.topic_id; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_topics.topic_id IS 'Unique topic identifier (primary key)';

--
-- TOC entry 5180 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.course_id; Type: COMMENT; Schema: course; Owner: postgres
--
COMMENT ON COLUMN course.course_topics.course_id IS 'Identifier of the course to which the topic belongs (foreign key)';

--
-- TOC entry 5181 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.user_id; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_topics.user_id IS 'Identifier of the user who owns the topic (foreign key)';

--
-- TOC entry 5182 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.title; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_topics.title IS 'Topic title';

--
-- TOC entry 5183 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.material; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_topics.material IS 'Topic materials (e.g., lecture text or links)';

--
-- TOC entry 5184 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.grade; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_topics.grade IS 'Grade for the topic (from 0 to 5)';

--
-- TOC entry 5185 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.completed_date; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_topics.completed_date IS 'Date the topic was completed';

--
-- TOC entry 5186 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.created_at; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_topics.created_at IS 'Date and time the topic was created';

--
-- TOC entry 5187 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN course_topics.updated_at; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.course_topics.updated_at IS 'Date and time the topic was last updated';

--
-- TOC entry 238 (class 1259 OID 26793)
-- Name: courses; Type: TABLE; Schema: course; Owner: postgres
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
-- Name: TABLE courses; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON TABLE course.courses IS 'Table for storing user courses';

--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN courses.course_id; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.courses.course_id IS 'Unique course identifier (primary key)';

--
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN courses.user_id; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.courses.user_id IS 'Identifier of the user who owns the course (foreign key)';

--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN courses.title; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.courses.title IS 'Course title (unique within the user)';

--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN courses.description; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.courses.description IS 'Course description';

--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN courses.created_at; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.courses.created_at IS 'Date and time the course was created';

--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN courses.updated_at; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.courses.updated_at IS 'Date and time the course was last updated';

--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 238
-- Name: COLUMN courses.status_id; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON COLUMN course.courses.status_id IS 'Identifier of the course status (reference to course_statuses)';

--
-- TOC entry 257 (class 1259 OID 27744)
-- Name: course_grades; Type: VIEW; Schema: course; Owner: postgres
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
-- Name: VIEW course_grades; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON VIEW course.course_grades IS 'View calculating the average grade (final_grade) for topics in each course from the courses table. Includes course_id, user_id, title, description, and status (from course_statuses). Used for performance analysis.';

--
-- TOC entry 248 (class 1259 OID 26899)
-- Name: course_progress; Type: VIEW; Schema: course; Owner: postgres
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
-- Name: VIEW course_progress; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON VIEW course.course_progress IS 'View showing course completion progress: total topics (total_topics), completed topics (completed_topics), and completion percentage (completion_percentage). Used to track user progress.';

--
-- TOC entry 239 (class 1259 OID 26807)
-- Name: course_topics_topic_id_seq; Type: SEQUENCE; Schema: course; Owner: postgres
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
-- Name: course_topics_topic_id_seq; Type: SEQUENCE OWNED BY; Schema: course; Owner: postgres
--

ALTER SEQUENCE course.course_topics_topic_id_seq OWNED BY course.course_topics.topic_id;

--
-- TOC entry 5199 (class 0 OID 0)
-- Dependencies: 239
-- Name: SEQUENCE course_topics_topic_id_seq; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON SEQUENCE course.course_topics_topic_id_seq IS 'Sequence for generating unique identifiers (topic_id) in the course_topics table, which stores course topics.';

--
-- TOC entry 237 (class 1259 OID 26792)
-- Name: courses_course_id_seq; Type: SEQUENCE; Schema: course; Owner: postgres
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
-- Name: courses_course_id_seq; Type: SEQUENCE OWNED BY; Schema: course; Owner: postgres
--

ALTER SEQUENCE course.courses_course_id_seq OWNED BY course.courses.course_id;

--
-- TOC entry 5201 (class 0 OID 0)
-- Dependencies: 237
-- Name: SEQUENCE courses_course_id_seq; Type: COMMENT; Schema: course; Owner: postgres
--

COMMENT ON SEQUENCE course.courses_course_id_seq IS 'Sequence for generating unique identifiers (course_id) in the courses table, storing user courses.';

--
-- TOC entry 224 (class 1259 OID 26513)
-- Name: finance_categories; Type: TABLE; Schema: finance; Owner: postgres
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
-- Name: TABLE finance_categories; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON TABLE finance.finance_categories IS 'Table for storing user financial operation categories';


--
-- TOC entry 5203 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN finance_categories.category_id; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_categories.category_id IS 'Unique category identifier (primary key)';


--
-- TOC entry 5204 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN finance_categories.user_id; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_categories.user_id IS 'Identifier of the user who owns the category (foreign key)';


--
-- TOC entry 5205 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN finance_categories.name; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_categories.name IS 'Category name (unique within the user)';


--
-- TOC entry 5206 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN finance_categories.created_at; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_categories.created_at IS 'Date and time the category was created';


--
-- TOC entry 5207 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN finance_categories.updated_at; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_categories.updated_at IS 'Date and time the category was last updated';


--
-- TOC entry 5208 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN finance_categories.type_id; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_categories.type_id IS 'Identifier of the category type (reference to finance_types)';


--
-- TOC entry 223 (class 1259 OID 26512)
-- Name: finance_categories_category_id_seq; Type: SEQUENCE; Schema: finance; Owner: postgres
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
-- Name: finance_categories_category_id_seq; Type: SEQUENCE OWNED BY; Schema: finance; Owner: postgres
--

ALTER SEQUENCE finance.finance_categories_category_id_seq OWNED BY finance.finance_categories.category_id;


--
-- TOC entry 5210 (class 0 OID 0)
-- Dependencies: 223
-- Name: SEQUENCE finance_categories_category_id_seq; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON SEQUENCE finance.finance_categories_category_id_seq IS 'Sequence for generating unique identifiers (category_id) in the finance_categories table, which stores user financial operation categories.';


--
-- TOC entry 249 (class 1259 OID 27221)
-- Name: finance_types; Type: TABLE; Schema: finance; Owner: postgres
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
-- Name: TABLE finance_types; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON TABLE finance.finance_types IS 'Reference table for financial operation types (Income, Expense). ';


--
-- TOC entry 5212 (class 0 OID 0)
-- Dependencies: 249
-- Name: COLUMN finance_types.type_id; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_types.type_id IS 'Unique type identifier';


--
-- TOC entry 5213 (class 0 OID 0)
-- Dependencies: 249
-- Name: COLUMN finance_types.name; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_types.name IS 'Type name (e.g., Income, Expense)';


--
-- TOC entry 5214 (class 0 OID 0)
-- Dependencies: 249
-- Name: COLUMN finance_types.created_at; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finance_types.created_at IS 'Date and time the record was created';


--
-- TOC entry 226 (class 1259 OID 26527)
-- Name: finances; Type: TABLE; Schema: finance; Owner: postgres
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
-- Name: TABLE finances; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON TABLE finance.finances IS 'Table for tracking user financial operations';


--
-- TOC entry 5216 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN finances.finance_id; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finances.finance_id IS 'Unique financial operation identifier (primary key)';


--
-- TOC entry 5217 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN finances.user_id; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finances.user_id IS 'Identifier of the user who performed the operation (foreign key)';


--
-- TOC entry 5218 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN finances.category_id; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finances.category_id IS 'Identifier of the operation category (foreign key)';


--
-- TOC entry 5219 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN finances.amount; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finances.amount IS 'Operation amount, positive for income, negative for expenses';


--
-- TOC entry 5220 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN finances.transaction_date; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finances.transaction_date IS 'Date of the operation';


--
-- TOC entry 5221 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN finances.note; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finances.note IS 'Note or comment on the operation';


--
-- TOC entry 5222 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN finances.created_at; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finances.created_at IS 'Date and time the operation record was created';


--
-- TOC entry 5223 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN finances.updated_at; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON COLUMN finance.finances.updated_at IS 'Date and time the record was last updated';


--
-- TOC entry 225 (class 1259 OID 26526)
-- Name: finances_finance_id_seq; Type: SEQUENCE; Schema: finance; Owner: postgres
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
-- Name: finances_finance_id_seq; Type: SEQUENCE OWNED BY; Schema: finance; Owner: postgres
--

ALTER SEQUENCE finance.finances_finance_id_seq OWNED BY finance.finances.finance_id;


--
-- TOC entry 5225 (class 0 OID 0)
-- Dependencies: 225
-- Name: SEQUENCE finances_finance_id_seq; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON SEQUENCE finance.finances_finance_id_seq IS 'Sequence for generating unique identifiers (finance_id) in the finances table, which stores user financial operations.';


--
-- TOC entry 259 (class 1259 OID 28710)
-- Name: financial_summary; Type: VIEW; Schema: finance; Owner: postgres
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
-- Name: VIEW financial_summary; Type: COMMENT; Schema: finance; Owner: postgres
--

COMMENT ON VIEW finance.financial_summary IS 'View aggregating income (total_income), expenses (total_expense), and balance (balance) per user by month and year based on the finances table.';


--
-- TOC entry 232 (class 1259 OID 26711)
-- Name: habit_categories; Type: TABLE; Schema: habits; Owner: postgres
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
-- Name: TABLE habit_categories; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON TABLE habits.habit_categories IS 'Table for storing user habit categories';


--
-- TOC entry 5228 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN habit_categories.category_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_categories.category_id IS 'Unique category identifier (primary key)';


--
-- TOC entry 5229 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN habit_categories.user_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_categories.user_id IS 'Identifier of the user who owns the category (foreign key)';


--
-- TOC entry 5230 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN habit_categories.name; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_categories.name IS 'Category name (unique within the user)';


--
-- TOC entry 5231 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN habit_categories.created_at; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_categories.created_at IS 'Date and time the category was created';


--
-- TOC entry 5232 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN habit_categories.updated_at; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_categories.updated_at IS 'Date and time the category was last updated';


--
-- TOC entry 231 (class 1259 OID 26710)
-- Name: habit_categories_category_id_seq; Type: SEQUENCE; Schema: habits; Owner: postgres
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
-- Name: habit_categories_category_id_seq; Type: SEQUENCE OWNED BY; Schema: habits; Owner: postgres
--

ALTER SEQUENCE habits.habit_categories_category_id_seq OWNED BY habits.habit_categories.category_id;


--
-- TOC entry 5234 (class 0 OID 0)
-- Dependencies: 231
-- Name: SEQUENCE habit_categories_category_id_seq; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON SEQUENCE habits.habit_categories_category_id_seq IS 'Sequence for generating unique identifiers (category_id) in the habit_categories table, which stores user habit categories.';


--
-- TOC entry 255 (class 1259 OID 27718)
-- Name: habit_frequencies; Type: TABLE; Schema: habits; Owner: postgres
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
-- Name: TABLE habit_frequencies; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON TABLE habits.habit_frequencies IS 'Reference table for habit frequencies (Daily, Every two days, Weekly, Monthly). ';


--
-- TOC entry 5236 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN habit_frequencies.frequency_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_frequencies.frequency_id IS 'Unique frequency identifier';


--
-- TOC entry 5237 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN habit_frequencies.name; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_frequencies.name IS 'Frequency name (e.g., Daily, Weekly)';


--
-- TOC entry 5238 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN habit_frequencies.created_at; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_frequencies.created_at IS 'Date and time the record was created';


--
-- TOC entry 236 (class 1259 OID 26744)
-- Name: habit_logs; Type: TABLE; Schema: habits; Owner: postgres
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
-- Name: TABLE habit_logs; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON TABLE habits.habit_logs IS 'Table for storing habit completion logs';


--
-- TOC entry 5240 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN habit_logs.log_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_logs.log_id IS 'Unique log identifier (primary key)';


--
-- TOC entry 5241 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN habit_logs.habit_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_logs.habit_id IS 'Identifier of the habit to which the log belongs (foreign key)';


--
-- TOC entry 5242 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN habit_logs.log_date; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_logs.log_date IS 'Date of the habit log';


--
-- TOC entry 5243 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN habit_logs.is_completed; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_logs.is_completed IS 'Flag indicating habit completion on the specified date (true/false)';


--
-- TOC entry 5244 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN habit_logs.note; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_logs.note IS 'Note or comment on the log';


--
-- TOC entry 5245 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN habit_logs.created_at; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_logs.created_at IS 'Date and time the log was created';


--
-- TOC entry 5246 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN habit_logs.updated_at; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habit_logs.updated_at IS 'Date and time the log was last updated';


--
-- TOC entry 235 (class 1259 OID 26743)
-- Name: habit_logs_log_id_seq; Type: SEQUENCE; Schema: habits; Owner: postgres
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
-- Name: habit_logs_log_id_seq; Type: SEQUENCE OWNED BY; Schema: habits; Owner: postgres
--

ALTER SEQUENCE habits.habit_logs_log_id_seq OWNED BY habits.habit_logs.log_id;


--
-- TOC entry 5248 (class 0 OID 0)
-- Dependencies: 235
-- Name: SEQUENCE habit_logs_log_id_seq; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON SEQUENCE habits.habit_logs_log_id_seq IS 'Sequence for generating unique identifiers (log_id) in the habit_logs table, which stores habit completion records.';


--
-- TOC entry 234 (class 1259 OID 26726)
-- Name: habits; Type: TABLE; Schema: habits; Owner: postgres
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
-- Name: TABLE habits; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON TABLE habits.habits IS 'Table for storing user habits';


--
-- TOC entry 5250 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.habit_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.habit_id IS 'Unique habit identifier (primary key)';


--
-- TOC entry 5251 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.user_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.user_id IS 'Identifier of the user who owns the habit (foreign key)';


--
-- TOC entry 5252 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.category_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.category_id IS 'Identifier of the habit category (foreign key)';


--
-- TOC entry 5253 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.name; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.name IS 'Habit name (unique within the user)';


--
-- TOC entry 5254 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.start_date; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.start_date IS 'Start date of the habit';


--
-- TOC entry 5255 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.end_date; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.end_date IS 'End date of the habit (may be NULL)';


--
-- TOC entry 5256 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.created_at; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.created_at IS 'Date and time the habit was created';


--
-- TOC entry 5257 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.updated_at; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.updated_at IS 'Date and time the habit was last updated';


--
-- TOC entry 5258 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN habits.frequency_id; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON COLUMN habits.habits.frequency_id IS 'Identifier of the habit frequency (reference to habit_frequencies)';


--
-- TOC entry 233 (class 1259 OID 26725)
-- Name: habits_habit_id_seq; Type: SEQUENCE; Schema: habits; Owner: postgres
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
-- Name: habits_habit_id_seq; Type: SEQUENCE OWNED BY; Schema: habits; Owner: postgres
--

ALTER SEQUENCE habits.habits_habit_id_seq OWNED BY habits.habits.habit_id;


--
-- TOC entry 5260 (class 0 OID 0)
-- Dependencies: 233
-- Name: SEQUENCE habits_habit_id_seq; Type: COMMENT; Schema: habits; Owner: postgres
--

COMMENT ON SEQUENCE habits.habits_habit_id_seq IS 'Sequence for generating unique identifiers (habit_id) in the habits table, which stores user habits.';


--
-- TOC entry 251 (class 1259 OID 27686)
-- Name: task_priorities; Type: TABLE; Schema: todo; Owner: postgres
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
-- Name: TABLE task_priorities; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON TABLE todo.task_priorities IS 'Reference table for task priorities (Low, Medium, High).';


--
-- TOC entry 5262 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN task_priorities.priority_id; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.task_priorities.priority_id IS 'Unique priority identifier';


--
-- TOC entry 5263 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN task_priorities.name; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.task_priorities.name IS 'Priority name (e.g., Low, Medium)';


--
-- TOC entry 5264 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN task_priorities.created_at; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.task_priorities.created_at IS 'Date and time the record was created';


--
-- TOC entry 250 (class 1259 OID 27678)
-- Name: task_statuses; Type: TABLE; Schema: todo; Owner: postgres
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
-- Name: TABLE task_statuses; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON TABLE todo.task_statuses IS 'Reference table for task statuses (Planned, In Progress, Completed).';


--
-- TOC entry 5266 (class 0 OID 0)
-- Dependencies: 250
-- Name: COLUMN task_statuses.status_id; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.task_statuses.status_id IS 'Unique status identifier';


--
-- TOC entry 5267 (class 0 OID 0)
-- Dependencies: 250
-- Name: COLUMN task_statuses.name; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.task_statuses.name IS 'Status name (e.g., Planned, In Progress)';


--
-- TOC entry 5268 (class 0 OID 0)
-- Dependencies: 250
-- Name: COLUMN task_statuses.created_at; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.task_statuses.created_at IS 'Date and time the record was created';


--
-- TOC entry 228 (class 1259 OID 26675)
-- Name: todo_categories; Type: TABLE; Schema: todo; Owner: postgres
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
-- Name: TABLE todo_categories; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON TABLE todo.todo_categories IS 'Table for storing user task categories';


--
-- TOC entry 5270 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN todo_categories.category_id; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todo_categories.category_id IS 'Unique category identifier (primary key)';


--
-- TOC entry 5271 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN todo_categories.user_id; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todo_categories.user_id IS 'Identifier of the user who owns the category (foreign key)';


--
-- TOC entry 5272 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN todo_categories.name; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todo_categories.name IS 'Category name (unique within the user)';


--
-- TOC entry 5273 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN todo_categories.created_at; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todo_categories.created_at IS 'Date and time the category was created';


--
-- TOC entry 5274 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN todo_categories.updated_at; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todo_categories.updated_at IS 'Date and time the category was last updated';


--
-- TOC entry 227 (class 1259 OID 26674)
-- Name: todo_categories_category_id_seq; Type: SEQUENCE; Schema: todo; Owner: postgres
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
-- Name: todo_categories_category_id_seq; Type: SEQUENCE OWNED BY; Schema: todo; Owner: postgres
--

ALTER SEQUENCE todo.todo_categories_category_id_seq OWNED BY todo.todo_categories.category_id;


--
-- TOC entry 5276 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE todo_categories_category_id_seq; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON SEQUENCE todo.todo_categories_category_id_seq IS 'Sequence for generating unique identifiers (category_id) in the todo_categories table, which stores user task categories.';


--
-- TOC entry 230 (class 1259 OID 26689)
-- Name: todos; Type: TABLE; Schema: todo; Owner: postgres
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
-- Name: TABLE todos; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON TABLE todo.todos IS 'Table for storing user tasks';


--
-- TOC entry 5278 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.todo_id; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.todo_id IS 'Unique task identifier (primary key)';


--
-- TOC entry 5279 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.user_id; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.user_id IS 'Identifier of the user who owns the task (foreign key)';


--
-- TOC entry 5280 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.category_id; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.category_id IS 'Identifier of the task category (foreign key, may be NULL)';


--
-- TOC entry 5281 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.task; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.task IS 'Task description';


--
-- TOC entry 5282 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.due_date; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.due_date IS 'Task due date (may be NULL)';


--
-- TOC entry 5283 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.is_completed; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.is_completed IS 'Task completion flag (true/false)';


--
-- TOC entry 5284 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.completed_date; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.completed_date IS 'Task completion date (set by trigger when is_completed=true)';


--
-- TOC entry 5285 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.created_at; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.created_at IS 'Date and time the task was created';


--
-- TOC entry 5286 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.updated_at; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.updated_at IS 'Date and time the task was last updated';


--
-- TOC entry 5287 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN todos.task_priority_id; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON COLUMN todo.todos.task_priority_id IS 'Identifier of the task priority (reference to task_priorities)';


--
-- TOC entry 229 (class 1259 OID 26688)
-- Name: todos_todo_id_seq; Type: SEQUENCE; Schema: todo; Owner: postgres
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
-- Name: todos_todo_id_seq; Type: SEQUENCE OWNED BY; Schema: todo; Owner: postgres
--

ALTER SEQUENCE todo.todos_todo_id_seq OWNED BY todo.todos.todo_id;


--
-- TOC entry 5289 (class 0 OID 0)
-- Dependencies: 229
-- Name: SEQUENCE todos_todo_id_seq; Type: COMMENT; Schema: todo; Owner: postgres
--

COMMENT ON SEQUENCE todo.todos_todo_id_seq IS 'Sequence for generating unique identifiers (todo_id) in the todos table, which stores user tasks.';


--
-- TOC entry 254 (class 1259 OID 27710)
-- Name: expense_categories; Type: TABLE; Schema: trips; Owner: postgres
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
-- Name: TABLE expense_categories; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON TABLE trips.expense_categories IS 'Reference table for trip expense categories (Food, Transport, etc.). ';


--
-- TOC entry 5291 (class 0 OID 0)
-- Dependencies: 254
-- Name: COLUMN expense_categories.category_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.expense_categories.category_id IS 'Unique category identifier';


--
-- TOC entry 5292 (class 0 OID 0)
-- Dependencies: 254
-- Name: COLUMN expense_categories.name; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.expense_categories.name IS 'Category name (e.g., Food, Transport)';


--
-- TOC entry 5293 (class 0 OID 0)
-- Dependencies: 254
-- Name: COLUMN expense_categories.created_at; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.expense_categories.created_at IS 'Date and time the record was created';


--
-- TOC entry 258 (class 1259 OID 27818)
-- Name: expense_categories_category_id_seq; Type: SEQUENCE; Schema: trips; Owner: postgres
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
-- Name: expense_categories_category_id_seq; Type: SEQUENCE OWNED BY; Schema: trips; Owner: postgres
--

ALTER SEQUENCE trips.expense_categories_category_id_seq OWNED BY trips.expense_categories.category_id;


--
-- TOC entry 253 (class 1259 OID 27702)
-- Name: transportation_types; Type: TABLE; Schema: trips; Owner: postgres
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
-- Name: TABLE transportation_types; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON TABLE trips.transportation_types IS 'Reference table for transportation types (Airplane, Train, Bus, etc.). ';


--
-- TOC entry 5296 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN transportation_types.type_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.transportation_types.type_id IS 'Unique type identifier';


--
-- TOC entry 5297 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN transportation_types.name; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.transportation_types.name IS 'Type name (e.g., Airplane, Train)';


--
-- TOC entry 5298 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN transportation_types.created_at; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.transportation_types.created_at IS 'Date and time the record was created';


--
-- TOC entry 244 (class 1259 OID 26859)
-- Name: trip_routes; Type: TABLE; Schema: trips; Owner: postgres
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
-- Name: TABLE trip_routes; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON TABLE trips.trip_routes IS 'Table for storing trip routes';


--
-- TOC entry 5300 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.route_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.route_id IS 'Unique route identifier (primary key)';


--
-- TOC entry 5301 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.trip_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.trip_id IS 'Identifier of the trip to which the route belongs (foreign key)';


--
-- TOC entry 5302 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.location_order; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.location_order IS 'Location order in the route (unique within the trip)';


--
-- TOC entry 5303 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.location_name; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.location_name IS 'Location name';


--
-- TOC entry 5304 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.distance_km; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.distance_km IS 'Distance between route locations in kilometers';


--
-- TOC entry 5305 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.cost; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.cost IS 'Transportation cost (in user currency)';


--
-- TOC entry 5306 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.arrival_date; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.arrival_date IS 'Arrival date at the location';


--
-- TOC entry 5307 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.departure_date; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.departure_date IS 'Departure date from the location (may be NULL)';


--
-- TOC entry 5308 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.created_at; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.created_at IS 'Date and time the route was created';


--
-- TOC entry 5309 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.updated_at; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.updated_at IS 'Date and time the route was last updated';


--
-- TOC entry 5310 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN trip_routes.transportation_type_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_routes.transportation_type_id IS 'Identifier of the transportation type (reference to transportation_types)';


--
-- TOC entry 242 (class 1259 OID 26846)
-- Name: trips; Type: TABLE; Schema: trips; Owner: postgres
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
-- Name: TABLE trips; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON TABLE trips.trips IS 'Table for storing user trips';


--
-- TOC entry 5312 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN trips.trip_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trips.trip_id IS 'Unique trip identifier (primary key)';


--
-- TOC entry 5313 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN trips.user_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trips.user_id IS 'Identifier of the user who owns the trip (foreign key)';


--
-- TOC entry 5314 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN trips.name; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trips.name IS 'Trip name';


--
-- TOC entry 5315 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN trips.start_date; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trips.start_date IS 'Trip start date';


--
-- TOC entry 5316 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN trips.end_date; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trips.end_date IS 'Trip end date (may be NULL)';


--
-- TOC entry 5317 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN trips.created_at; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trips.created_at IS 'Date and time the trip record was created';


--
-- TOC entry 5318 (class 0 OID 0)
-- Dependencies: 242
-- Name: COLUMN trips.updated_at; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trips.updated_at IS 'Date and time the record was last updated';


--
-- TOC entry 245 (class 1259 OID 26873)
-- Name: trip_costs; Type: VIEW; Schema: trips; Owner: postgres
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
-- Name: trip_expenses; Type: TABLE; Schema: trips; Owner: postgres
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
-- Name: COLUMN trip_expenses.expense_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_expenses.expense_id IS 'Unique expense identifier (primary key)';


--
-- TOC entry 5320 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN trip_expenses.route_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_expenses.route_id IS 'Identifier of the route to which the expense belongs (foreign key)';


--
-- TOC entry 5321 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN trip_expenses.amount; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_expenses.amount IS 'Expense amount (in user currency)';


--
-- TOC entry 5322 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN trip_expenses.expense_date; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_expenses.expense_date IS 'Expense date';


--
-- TOC entry 5323 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN trip_expenses.note; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_expenses.note IS 'Note or comment on the expense';


--
-- TOC entry 5324 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN trip_expenses.created_at; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_expenses.created_at IS 'Date and time the expense record was created';


--
-- TOC entry 5325 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN trip_expenses.updated_at; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_expenses.updated_at IS 'Date and time the record was last updated';


--
-- TOC entry 5326 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN trip_expenses.expense_category_id; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON COLUMN trips.trip_expenses.expense_category_id IS 'Identifier of the expense category (reference to expense_categories)';


--
-- TOC entry 246 (class 1259 OID 26879)
-- Name: trip_expenses_expense_id_seq; Type: SEQUENCE; Schema: trips; Owner: postgres
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
-- Name: trip_expenses_expense_id_seq; Type: SEQUENCE OWNED BY; Schema: trips; Owner: postgres
--

ALTER SEQUENCE trips.trip_expenses_expense_id_seq OWNED BY trips.trip_expenses.expense_id;


--
-- TOC entry 5328 (class 0 OID 0)
-- Dependencies: 246
-- Name: SEQUENCE trip_expenses_expense_id_seq; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON SEQUENCE trips.trip_expenses_expense_id_seq IS 'Sequence for generating unique identifiers (expense_id) in the trip_expenses table, which stores route trip expenses.';


--
-- TOC entry 243 (class 1259 OID 26858)
-- Name: trip_routes_route_id_seq; Type: SEQUENCE; Schema: trips; Owner: postgres
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
-- Name: trip_routes_route_id_seq; Type: SEQUENCE OWNED BY; Schema: trips; Owner: postgres
--

ALTER SEQUENCE trips.trip_routes_route_id_seq OWNED BY trips.trip_routes.route_id;


--
-- TOC entry 5330 (class 0 OID 0)
-- Dependencies: 243
-- Name: SEQUENCE trip_routes_route_id_seq; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON SEQUENCE trips.trip_routes_route_id_seq IS 'Sequence for generating unique identifiers (route_id) in the trip_routes table, which stores stages of trip routes.';


--
-- TOC entry 241 (class 1259 OID 26845)
-- Name: trips_trip_id_seq; Type: SEQUENCE; Schema: trips; Owner: postgres
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
-- Name: trips_trip_id_seq; Type: SEQUENCE OWNED BY; Schema: trips; Owner: postgres
--

ALTER SEQUENCE trips.trips_trip_id_seq OWNED BY trips.trips.trip_id;


--
-- TOC entry 5332 (class 0 OID 0)
-- Dependencies: 241
-- Name: SEQUENCE trips_trip_id_seq; Type: COMMENT; Schema: trips; Owner: postgres
--

COMMENT ON SEQUENCE trips.trips_trip_id_seq IS 'Sequence for generating unique identifiers (trip_id) in the trips table, which stores user trip information.';


--
-- TOC entry 256 (class 1259 OID 27726)
-- Name: user_roles; Type: TABLE; Schema: user; Owner: postgres
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
-- Name: TABLE user_roles; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON TABLE "user".user_roles IS 'Reference table for user roles';


--
-- TOC entry 5334 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN user_roles.role_id; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".user_roles.role_id IS 'Unique role identifier';


--
-- TOC entry 5335 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN user_roles.name; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".user_roles.name IS 'Role name (e.g., Administrator, User)';


--
-- TOC entry 5336 (class 0 OID 0)
-- Dependencies: 256
-- Name: COLUMN user_roles.created_at; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".user_roles.created_at IS 'Date and time the record was created';


--
-- TOC entry 222 (class 1259 OID 26496)
-- Name: users; Type: TABLE; Schema: user; Owner: postgres
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
-- Name: TABLE users; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON TABLE "user".users IS 'Table for storing system user information';


--
-- TOC entry 5338 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN users.user_id; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".users.user_id IS 'Unique user identifier (primary key)';


--
-- TOC entry 5339 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN users.username; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".users.username IS 'Unique username (no duplicates allowed)';


--
-- TOC entry 5340 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN users.email; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".users.email IS 'User email (unique; format validated by regex)';


--
-- TOC entry 5341 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN users.first_name; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".users.first_name IS 'User first name';


--
-- TOC entry 5342 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN users.last_name; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".users.last_name IS 'User last name';


--
-- TOC entry 5343 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN users.updated_at; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".users.updated_at IS 'Date and time the record was last updated';


--
-- TOC entry 5344 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN users.role_id; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON COLUMN "user".users.role_id IS 'Identifier of the user role (reference to user_roles)';


--
-- TOC entry 221 (class 1259 OID 26495)
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: user; Owner: postgres
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
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: user; Owner: postgres
--

ALTER SEQUENCE "user".users_user_id_seq OWNED BY "user".users.user_id;


--
-- TOC entry 5346 (class 0 OID 0)
-- Dependencies: 221
-- Name: SEQUENCE users_user_id_seq; Type: COMMENT; Schema: user; Owner: postgres
--

COMMENT ON SEQUENCE "user".users_user_id_seq IS 'Sequence for generating unique identifiers (user_id) in the users table, which stores system user information.';


--
-- TOC entry 4835 (class 2604 OID 26811)
-- Name: course_topics topic_id; Type: DEFAULT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.course_topics ALTER COLUMN topic_id SET DEFAULT nextval('course.course_topics_topic_id_seq'::regclass);


--
-- TOC entry 4832 (class 2604 OID 26796)
-- Name: courses course_id; Type: DEFAULT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.courses ALTER COLUMN course_id SET DEFAULT nextval('course.courses_course_id_seq'::regclass);


--
-- TOC entry 4809 (class 2604 OID 26516)
-- Name: finance_categories category_id; Type: DEFAULT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finance_categories ALTER COLUMN category_id SET DEFAULT nextval('finance.finance_categories_category_id_seq'::regclass);


--
-- TOC entry 4812 (class 2604 OID 26530)
-- Name: finances finance_id; Type: DEFAULT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finances ALTER COLUMN finance_id SET DEFAULT nextval('finance.finances_finance_id_seq'::regclass);


--
-- TOC entry 4822 (class 2604 OID 26714)
-- Name: habit_categories category_id; Type: DEFAULT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_categories ALTER COLUMN category_id SET DEFAULT nextval('habits.habit_categories_category_id_seq'::regclass);


--
-- TOC entry 4828 (class 2604 OID 26747)
-- Name: habit_logs log_id; Type: DEFAULT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_logs ALTER COLUMN log_id SET DEFAULT nextval('habits.habit_logs_log_id_seq'::regclass);


--
-- TOC entry 4825 (class 2604 OID 26729)
-- Name: habits habit_id; Type: DEFAULT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habits ALTER COLUMN habit_id SET DEFAULT nextval('habits.habits_habit_id_seq'::regclass);


--
-- TOC entry 4815 (class 2604 OID 26678)
-- Name: todo_categories category_id; Type: DEFAULT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todo_categories ALTER COLUMN category_id SET DEFAULT nextval('todo.todo_categories_category_id_seq'::regclass);


--
-- TOC entry 4818 (class 2604 OID 26692)
-- Name: todos todo_id; Type: DEFAULT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todos ALTER COLUMN todo_id SET DEFAULT nextval('todo.todos_todo_id_seq'::regclass);


--
-- TOC entry 4853 (class 2604 OID 27819)
-- Name: expense_categories category_id; Type: DEFAULT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.expense_categories ALTER COLUMN category_id SET DEFAULT nextval('trips.expense_categories_category_id_seq'::regclass);


--
-- TOC entry 4844 (class 2604 OID 26883)
-- Name: trip_expenses expense_id; Type: DEFAULT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_expenses ALTER COLUMN expense_id SET DEFAULT nextval('trips.trip_expenses_expense_id_seq'::regclass);


--
-- TOC entry 4841 (class 2604 OID 26862)
-- Name: trip_routes route_id; Type: DEFAULT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_routes ALTER COLUMN route_id SET DEFAULT nextval('trips.trip_routes_route_id_seq'::regclass);


--
-- TOC entry 4838 (class 2604 OID 26849)
-- Name: trips trip_id; Type: DEFAULT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trips ALTER COLUMN trip_id SET DEFAULT nextval('trips.trips_trip_id_seq'::regclass);


--
-- TOC entry 4807 (class 2604 OID 26499)
-- Name: users user_id; Type: DEFAULT; Schema: user; Owner: postgres
--

ALTER TABLE ONLY "user".users ALTER COLUMN user_id SET DEFAULT nextval('"user".users_user_id_seq'::regclass);


--
-- TOC entry 5159 (class 0 OID 27694)
-- Dependencies: 252
-- Data for Name: course_statuses; Type: TABLE DATA; Schema: course; Owner: postgres
--

INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (1, 'Planned', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (2, 'In Progress', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (3, 'Completed', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (4, 'Paused', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (5, 'Cancelled', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (6, 'Pending', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (7, 'Scheduled', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (8, 'In Development', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (9, 'In Testing', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (10, 'Archive', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (11, 'Under Review', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (12, 'Approved', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (13, 'Launched', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (14, 'Awaiting Evaluation', '2025-05-13 12:24:28.911238');
INSERT INTO course.course_statuses (status_id, name, created_at) VALUES (15, 'Completed with Honors', '2025-05-13 12:24:28.911238');


--
-- TOC entry 5149 (class 0 OID 26808)
-- Dependencies: 240
-- Data for Name: course_topics; Type: TABLE DATA; Schema: course; Owner: postgres
--

INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (1, 1, 3, 'Introduction to Algorithms', 'Basic concepts, algorithm complexity', 4.50, '2025-01-15', '2025-01-10 09:00:00', '2025-01-15 12:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (2, 1, 3, 'Sorting', 'Bubble, quick, merge sort', 4.75, '2025-01-22', '2025-01-17 09:00:00', '2025-01-22 12:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (3, 1, 3, 'Graph search', 'BFS, DFS, Dijkstra''s algorithm', 5.00, '2025-01-29', '2025-01-24 09:00:00', '2025-01-29 12:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (4, 1, 3, 'Dynamic programming', 'Knapsack problem, Fibonacci numbers', 4.25, '2025-02-05', '2025-01-31 09:00:00', '2025-02-05 12:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (5, 1, 3, 'Greedy algorithms', 'Huffman algorithm, activity selection problem', 4.50, '2025-02-12', '2025-02-07 09:00:00', '2025-02-12 12:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (6, 2, 4, 'HTML basics', 'Document structure, tags', NULL, NULL, '2025-02-01 10:00:00', '2025-02-01 10:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (7, 2, 4, 'CSS for beginners', 'Selectors, properties, box model', NULL, NULL, '2025-02-08 10:00:00', '2025-02-08 10:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (8, 2, 4, 'Responsive design', 'Media queries, flexbox, grid', 3.75, '2025-02-15', '2025-02-10 10:00:00', '2025-02-15 12:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (9, 2, 4, 'UX/UI basics', 'Usability principles, prototyping', NULL, NULL, '2025-02-17 10:00:00', '2025-02-17 10:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (10, 3, 5, 'Introduction to ML', 'Basic concepts, task types', 4.00, '2025-03-01', '2025-02-20 11:00:00', '2025-03-01 13:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (11, 3, 5, 'Linear regression', 'Least squares method', 4.25, '2025-03-08', '2025-03-03 11:00:00', '2025-03-08 13:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (12, 3, 5, 'Classification', 'Logistic regression, SVM', 4.50, '2025-03-15', '2025-03-10 11:00:00', '2025-03-15 13:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (13, 3, 5, 'Decision trees', 'Construction and interpretation', NULL, NULL, '2025-03-17 11:00:00', '2025-03-17 11:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (14, 4, 6, 'Python syntax', 'Variables, operators, data types', 4.75, '2025-03-10', '2025-03-01 14:00:00', '2025-03-10 16:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (15, 4, 6, 'Functions', 'Definition, arguments, return values', 4.50, '2025-03-17', '2025-03-12 14:00:00', '2025-03-17 16:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (16, 4, 6, 'Working with files', 'Reading and writing files', 4.25, '2025-03-24', '2025-03-19 14:00:00', '2025-03-24 16:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (17, 4, 6, 'OOP in Python', 'Classes, objects, inheritance', NULL, NULL, '2025-03-26 14:00:00', '2025-03-26 14:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (18, 5, 7, 'Personal budget', 'Income and expenses, planning', 3.50, '2025-04-05', '2025-04-01 15:00:00', '2025-04-05 17:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (19, 5, 7, 'Investments', 'Main instruments, risks', 4.00, '2025-04-12', '2025-04-07 15:00:00', '2025-04-12 17:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (20, 5, 7, 'Loans and borrowings', 'Types of loans, overpayment', NULL, NULL, '2025-04-14 15:00:00', '2025-04-14 15:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (21, 6, 10, 'Networking basics', 'OSI model, TCP/IP', NULL, NULL, '2025-04-20 16:00:00', '2025-04-20 16:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (22, 6, 10, 'IP addressing', 'Address classes, subnets', 4.25, '2025-04-27', '2025-04-22 16:00:00', '2025-04-27 18:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (23, 7, 11, 'Introduction to Java', 'Installing JDK, Hello World', 4.50, '2025-05-01', '2025-04-25 17:00:00', '2025-05-01 19:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (24, 7, 11, 'Data types', 'Primitive types, objects', 4.75, '2025-05-08', '2025-05-03 17:00:00', '2025-05-08 19:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (25, 7, 11, 'Control structures', 'Conditions, loops', 4.25, '2025-05-15', '2025-05-10 17:00:00', '2025-05-15 19:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (26, 8, 12, 'UX basics', 'User research, personas', 4.00, '2025-05-05', '2025-05-01 18:00:00', '2025-05-05 20:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (27, 8, 12, 'Design tools', 'Figma, Sketch, Adobe XD', 4.50, '2025-05-12', '2025-05-07 18:00:00', '2025-05-12 20:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (28, 9, 13, 'Ancient art', 'Ancient Greece and Rome', 4.75, '2025-05-10', '2025-05-05 19:00:00', '2025-05-10 21:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (29, 9, 13, 'Renaissance', 'Leonardo, Michelangelo, Raphael', 5.00, '2025-05-17', '2025-05-12 19:00:00', '2025-05-17 21:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (30, 10, 14, 'Economics basics', 'Supply and demand', 4.25, '2025-05-15', '2025-05-10 20:00:00', '2025-05-15 22:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (31, 10, 14, 'Macroeconomics', 'GDP, inflation, unemployment', NULL, NULL, '2025-05-17 20:00:00', '2025-05-17 20:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (32, 11, 15, 'Introduction to Data Science', 'Field overview, tools', 4.50, '2025-05-20', '2025-05-15 09:00:00', '2025-05-20 11:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (33, 12, 17, 'DevOps basics', 'CI/CD, containerization', NULL, NULL, '2025-05-22 10:00:00', '2025-05-22 10:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (34, 13, 18, 'Photoshop interface', 'Toolbars, layers', 3.75, '2025-05-25', '2025-05-20 11:00:00', '2025-05-25 13:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (35, 14, 19, 'SMM strategies', 'Content plan, targeting', 4.00, '2025-05-27', '2025-05-22 12:00:00', '2025-05-27 14:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (36, 15, 20, 'Introduction to mobile development', 'Platforms, tools', NULL, NULL, '2025-05-29 13:00:00', '2025-05-29 13:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (37, 16, 22, 'Project management basics', 'Methodologies, planning', 4.25, '2025-06-01', '2025-05-27 14:00:00', '2025-06-01 16:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (38, 17, 23, '3D modeling for beginners', 'Blender interface', 4.50, '2025-06-03', '2025-05-29 15:00:00', '2025-06-03 17:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (39, 18, 24, 'Basics of communication psychology', 'Verbal and nonverbal communication', NULL, NULL, '2025-06-05 16:00:00', '2025-06-05 16:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (40, 19, 25, 'Cybersecurity', 'Main threats, protection', 4.75, '2025-06-07', '2025-06-02 17:00:00', '2025-06-07 19:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (41, 20, 26, 'Introduction to Power BI', 'Interface, data connections', 4.00, '2025-06-09', '2025-06-04 18:00:00', '2025-06-09 20:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (42, 21, 27, 'SQL basics', 'SELECT, JOIN, GROUP BY', 4.50, '2025-06-11', '2025-06-06 19:00:00', '2025-06-11 21:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (43, 22, 28, 'Phishing and social engineering', 'Protection methods', NULL, NULL, '2025-06-13 20:00:00', '2025-06-13 20:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (44, 23, 29, 'Introduction to Unity', 'Interface, scene creation', 3.75, '2025-06-15', '2025-06-10 21:00:00', '2025-06-15 23:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (45, 24, 30, 'Physics of motion', 'Kinematics, dynamics', 4.25, '2025-06-17', '2025-06-12 22:00:00', '2025-06-17 00:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (46, 25, 31, 'Accounting basics', 'Balance sheet, income statement', NULL, NULL, '2025-06-19 23:00:00', '2025-06-19 23:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (47, 26, 32, 'CSS animations', 'Transitions, keyframes', 4.50, '2025-06-21', '2025-06-16 00:00:00', '2025-06-21 02:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (48, 27, 33, 'Architectural patterns', 'MVC, MVVM, microservices', 4.75, '2025-06-23', '2025-06-18 01:00:00', '2025-06-23 03:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (49, 28, 35, 'Web typography', 'Fonts, kerning, leading', NULL, NULL, '2025-06-25 02:00:00', '2025-06-25 02:00:00');
INSERT INTO course.course_topics (topic_id, course_id, user_id, title, material, grade, completed_date, created_at, updated_at) VALUES (50, 29, 38, 'SEO content optimization', 'Keywords, meta tags', 4.00, '2025-06-27', '2025-06-22 03:00:00', '2025-06-27 05:00:00');


--
-- TOC entry 5147 (class 0 OID 26793)
-- Dependencies: 238
-- Data for Name: courses; Type: TABLE DATA; Schema: course; Owner: postgres
--

INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (1, 3, 'Algorithms', 'Data structures study', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (3, 5, 'Machine Learning', 'Introduction to ML', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (5, 7, 'Financial Literacy', 'Personal finance management', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (7, 11, 'Java from Scratch', 'Java fundamentals', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (8, 12, 'UX/UI Design', 'Interface design', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (9, 13, 'History of Art', 'Immersion into art history', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (10, 14, 'Economics for Everyone', 'Economic fundamentals', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id)VALUES (11, 15, 'Data Science', 'Data Science', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (14, 19, 'Social Media Marketing', 'Promotion on Instagram and TikTok', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (17, 23, '3D Modeling', 'Creating 3D models', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (18, 24, 'Communication Psychology', 'Effective communication skills', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (28, 35, 'Typography', 'Working with fonts and text', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (30, 39, 'JavaScript Basics', 'Hands-on JS course', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (31, 41, 'Technical English', 'IT terms and vocabulary', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (32, 42, 'Philosophy', 'Basics of philosophy', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (33, 43, 'Business Analysis', 'Requirements gathering and analysis', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id)VALUES (34, 45, 'Computer Vision', 'Computer Vision', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id)VALUES (35, 48, 'Data Interpretation', 'Working with Datasets', '2025-06-13 17:30:08.289376', '2025-06-13 17:30:08.289376', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (36, 45, 'REST API Development', 'Building APIs using Flask and Django', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (37, 35, 'NoSQL Databases', 'Data storage and processing in MongoDB and Firebase', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (38, 9, 'Creative Writing', 'Developing literary writing skills', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (39, 19, 'Django Framework', 'Building web applications with Django', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (40, 32, 'Working with Telegram API', 'Integration with messengers', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (41, 29, 'UI Animations', 'Effects and smoothness in interfaces', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (42, 42, 'Advanced Excel', 'Formulas, pivot tables and macros', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (43, 36, 'TypeScript Course', 'Working with typing in JavaScript', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (44, 18, 'Public Speaking', 'Confidence before an audience', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (45, 25, 'Soft Skills in IT', 'Communication and time management', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (46, 46, 'Working with JSON and XML', 'Data exchange formats', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (47, 2, 'Kotlin Development', 'Mobile development for Android', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (48, 29, 'Client-Server Architecture', 'Data exchange between client and server', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (49, 39, 'Machine Learning in Finance', 'Financial forecasting and analysis with ML', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (50, 6, 'Neural Networks from Scratch', 'Basic principles of neural networks and training', '2025-06-13 17:31:21.720938', '2025-06-13 17:31:21.720938', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (2, 4, 'Web Design', 'Website creation', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (4, 6, 'Python Basics', 'Learning programming in Python', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (6, 10, 'Networking Technologies', 'Configuring networks and protocols', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 2);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (12, 17, 'Introduction to DevOps', 'Automation of development processes', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (13, 18, 'Photoshop for Beginners', 'Working with images', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (16, 22, 'Project Management', 'Project management', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (15, 20, 'Mobile App Development', 'Creating Android and iOS applications', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (19, 25, 'Information Security', 'Information protection', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (20, 26, 'Power BI for Analysts', 'Data visualization', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (21, 27, 'MySQL Databases', 'Database administration', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (22, 28, 'Cybersecurity', 'Internet safety', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (23, 29, 'Game Development', 'Creating games in Unity', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (24, 30, 'Physics for Humanities', 'Physics in simple terms', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (25, 31, 'Financial Accounting', 'Bookkeeping', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 1);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (26, 32, 'CSS Styling', 'Interface styling', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (27, 33, 'Software Architecture', 'Architecture modeling', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);
INSERT INTO course.courses (course_id, user_id, title, description, created_at, updated_at, status_id) VALUES (29, 38, 'SEO Optimization', 'Website promotion', '2025-06-13 17:30:08.289376', '2025-06-13 17:51:17.527082', 3);


--
-- TOC entry 5133 (class 0 OID 26513)
-- Dependencies: 224
-- Data for Name: finance_categories; Type: TABLE DATA; Schema: finance; Owner: postgres
--

INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (17, 30, 'Salary', '2025-05-13 19:08:15.817536', '2025-06-13 19:03:24.993625', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (19, 34, 'Groceries', '2025-05-13 19:08:15.817536', '2025-06-13 19:03:24.993625', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (23, 35, 'Groceries', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (28, 37, 'Groceries', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (30, 25, 'Groceries', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (32, 27, 'Salary', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (34, 39, 'Salary', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (36, 28, 'Salary', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (37, 42, 'Groceries', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (39, 21, 'Groceries', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (1, 1, 'Salary', '2025-05-13 15:15:21.231663', '2025-05-13 12:02:13.848552', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (3, 3, 'Freelance', '2025-05-13 00:28:47.342729', '2025-05-13 12:02:13.848552', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (4, 4, 'Utilities', '2025-05-13 09:28:55.49417', '2025-05-13 12:02:13.848552', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (8, 8, 'Freelance', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (10, 10, 'Investments', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238', 3);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (12, 12, 'Dividends', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238', 14);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (14, 14, 'Bonus', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238', 15);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (15, 15, 'Clothing', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (18, 2, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (20, 10, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (21, 12, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (22, 12, 'Groceries', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (24, 8, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (25, 6, 'Groceries', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (26, 11, 'Groceries', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (27, 14, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (29, 1, 'Groceries', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (31, 3, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (33, 4, 'Groceries', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (35, 15, 'Groceries', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (38, 4, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (40, 5, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (42, 13, 'Salary', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (73, 1, 'Rent', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (75, 3, 'Medicine', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (76, 4, 'Sports', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (78, 6, 'Electronics', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (79, 7, 'Gifts', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (80, 8, 'Hobbies', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (82, 10, 'Cafe', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (83, 11, 'Taxi', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (84, 12, 'Clothing', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (86, 14, 'Repairs', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (87, 15, 'Pets', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (88, 1, 'Freelance', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (90, 3, 'Savings', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 4);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (91, 4, 'Loans', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 5);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (92, 5, 'Donations', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 6);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (94, 7, 'Gifts', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 8);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (95, 8, 'Fines', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 9);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (96, 9, 'Taxes', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 10);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (97, 10, 'Insurance', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 11);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (98, 11, 'Rent', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 12);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (99, 12, 'Commissions', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 13);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (100, 13, 'Dividends', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 14);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (101, 14, 'Bonuses', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 15);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (102, 15, 'Bonuses', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (103, 1, 'Subscriptions', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (104, 2, 'Music', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (105, 3, 'Games', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (41, 44, 'Groceries', '2025-05-13 19:08:15.817536', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (74, 45, 'Education', '2025-06-13 19:01:10.287568', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (77, 46, 'Books', '2025-06-13 19:01:10.287568', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (81, 47, 'Cinema', '2025-06-13 19:01:10.287568', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (85, 48, 'Cosmetics', '2025-06-13 19:01:10.287568', '2025-06-13 19:04:31.435453', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (89, 49, 'Investments', '2025-06-13 19:01:10.287568', '2025-06-13 19:04:31.435453', 3);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (93, 22, 'Debt Repayment', '2025-06-13 19:01:10.287568', '2025-06-13 19:04:31.435453', 7);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (2, 34, 'Groceries', '2025-05-13 18:32:20.637705', '2025-06-13 19:05:54.367848', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (5, 18, 'Bonuses', '2025-05-13 11:33:49.707702', '2025-06-13 19:05:54.367848', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (6, 22, 'Salary', '2025-05-13 12:24:28.911238', '2025-06-13 19:05:54.367848', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (7, 50, 'Groceries', '2025-05-13 12:24:28.911238', '2025-06-13 19:05:54.367848', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (9, 22, 'Transport', '2025-05-13 12:24:28.911238', '2025-06-13 19:05:54.367848', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (11, 27, 'Utilities', '2025-05-13 12:24:28.911238', '2025-06-13 19:05:54.367848', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (13, 14, 'Entertainment', '2025-05-13 12:24:28.911238', '2025-06-13 19:05:54.367848', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (106, 4, 'Travel', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (107, 5, 'Fitness', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (108, 6, 'Beauty', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (109, 7, 'Children', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (110, 8, 'Car', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (111, 9, 'Business', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (112, 10, 'Stocks', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 3);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (113, 11, 'Bonds', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 3);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (114, 12, 'Real Estate', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 3);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (115, 13, 'Cryptocurrency', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 3);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (116, 14, 'Funds', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 3);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (117, 15, 'Business Projects', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 1);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (118, 1, 'Training', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (119, 2, 'Courses', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (120, 3, 'Conferences', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (121, 4, 'Seminars', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
INSERT INTO finance.finance_categories (category_id, user_id, name, created_at, updated_at, type_id) VALUES (122, 5, 'Webinars', '2025-06-13 19:01:10.287568', '2025-06-13 19:01:10.287568', 2);
--
-- TOC entry 5156 (class 0 OID 27221)
-- Dependencies: 249
-- Data for Name: finance_types; Type: TABLE DATA; Schema: finance; Owner: postgres
--

INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (2, 'Expense', '2025-05-13 12:02:13.848552', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (3, 'Investments', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (4, 'Savings', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (5, 'Credit', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (6, 'Donations', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (7, 'Debt Repayment', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (8, 'Gift', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (9, 'Fine', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (10, 'Taxes', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (11, 'Insurance', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (12, 'Rent', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (13, 'Commission', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (14, 'Dividends', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (15, 'Bonus', '2025-05-13 12:24:28.911238', false);
INSERT INTO finance.finance_types (type_id, name, created_at, is_income) VALUES (1, 'Income', '2025-05-13 12:02:13.848552', true);


--
-- TOC entry 5135 (class 0 OID 26527)
-- Dependencies: 226
-- Data for Name: finances; Type: TABLE DATA; Schema: finance; Owner: postgres
--

INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (194, 30, 2, -120.50, '2025-06-16', 'Groceries', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (195, 31, 4, -75.30, '2025-06-17', 'Cafe', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (196, 32, 7, -350.00, '2025-06-18', 'Utilities', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (197, 33, 9, -200.00, '2025-06-19', 'Transport', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (198, 34, 11, -45.90, '2025-06-20', 'Coffee', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (1, 1, 1, 1500.00, '2025-01-15', 'January salary', '2025-01-15 00:00:47.57304', '2025-05-13 01:08:12.8578');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (2, 2, 2, -500.00, '2025-02-10', 'Groceries for the week', '2025-02-10 00:00:04.303631', '2025-05-13 01:08:12.8578');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (3, 3, 3, 2000.00, '2025-03-05', 'Client project', '2025-03-05 00:00:01.742209', '2025-05-13 01:08:12.8578');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (4, 4, 4, -300.00, '2025-04-20', 'Electricity and water bill', '2025-04-20 00:00:32.445042', '2025-05-13 01:08:12.8578');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (5, 5, 5, 1000.00, '2025-05-01', 'Annual bonus', '2025-05-01 00:00:41.248741', '2025-05-13 01:08:12.8578');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (199, 35, 13, -600.00, '2025-06-21', 'Clothes', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (200, 36, 15, -90.20, '2025-06-22', 'Books', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (201, 37, 2, -150.00, '2025-06-23', 'Cinema', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (202, 38, 4, -85.40, '2025-06-24', 'Groceries', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (203, 39, 7, -400.00, '2025-06-25', 'Utilities', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (204, 40, 9, -250.00, '2025-06-26', 'Taxi', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (205, 41, 11, -55.60, '2025-06-27', 'Lunch', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (206, 42, 13, -180.00, '2025-06-28', 'Stationery', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (207, 43, 15, -95.30, '2025-06-29', 'Groceries', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (208, 44, 2, -500.00, '2025-06-30', 'Utilities', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (6, 6, 6, 50000.00, '2025-05-06', 'Salary for May', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (7, 7, 7, -1500.00, '2025-05-07', 'Grocery purchase', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (8, 8, 8, 20000.00, '2025-05-08', 'Payment for project', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (9, 9, 9, -800.00, '2025-05-09', 'Travel pass', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (10, 10, 10, 10000.00, '2025-05-10', 'Stock investments', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (11, 11, 11, -3000.00, '2025-05-11', 'Apartment rent payment', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (12, 12, 12, 5000.00, '2025-05-12', 'Stock dividends', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (13, 13, 13, -2000.00, '2025-05-13', 'Cinema and dinner', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (14, 14, 14, 15000.00, '2025-05-14', 'Quarterly bonus', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (15, 15, 15, -2500.00, '2025-05-15', 'Shoe purchase', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (16, 3, 39, -2842.94, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (17, 3, 39, -1172.13, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (18, 4, 33, -2807.43, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (19, 4, 33, -2688.26, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (20, 4, 38, 9128.10, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (21, 4, 38, 6126.86, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (22, 5, 30, -1863.29, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (23, 5, 30, -1882.75, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (24, 5, 40, 7574.33, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (25, 5, 40, 5228.22, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (26, 6, 6, 7985.04, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (27, 6, 6, 8742.48, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (28, 6, 25, -2455.33, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (29, 6, 25, -2002.71, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (30, 7, 7, -2836.90, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (31, 7, 7, -2101.38, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (32, 7, 32, 6134.99, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (33, 7, 32, 9730.05, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (34, 8, 19, -2600.81, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (35, 8, 19, -1030.88, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (36, 8, 24, 9587.16, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (37, 8, 24, 6638.79, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (38, 9, 34, 7756.03, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (39, 9, 34, 9569.53, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (40, 9, 37, -2438.93, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (41, 9, 37, -1483.36, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (42, 10, 20, 8479.71, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (45, 10, 23, -2947.31, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (46, 11, 17, 6525.83, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (47, 11, 17, 8936.35, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (48, 11, 26, -2631.98, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (49, 11, 26, -2160.12, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (50, 12, 21, 9011.75, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (51, 12, 21, 5547.85, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (52, 12, 22, -1899.39, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (53, 12, 22, -2577.31, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (54, 13, 28, -1071.13, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (55, 13, 28, -1885.11, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (56, 13, 42, 9939.18, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (57, 13, 42, 5334.12, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (58, 14, 27, 8021.73, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (59, 14, 27, 7594.96, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (60, 14, 41, -1333.13, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (61, 14, 41, -1913.79, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (209, 45, 4, -350.00, '2025-07-01', 'Transport', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (210, 46, 7, -65.80, '2025-07-02', 'Coffee', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (211, 47, 9, -220.00, '2025-07-03', 'Lunch', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (212, 48, 11, -110.20, '2025-07-04', 'Groceries', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (213, 49, 13, -450.00, '2025-07-05', 'Utilities', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (214, 50, 15, -300.00, '2025-07-06', 'Transport', '2025-06-13 19:22:12.096738', '2025-06-13 19:22:12.096738');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (62, 15, 35, -1562.88, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (63, 15, 35, -2961.60, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (64, 15, 36, 8960.80, '2025-05-05', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (65, 15, 36, 8174.58, '2025-05-15', 'Income for May 2025', '2025-05-13 19:08:15.817536', '2025-05-13 19:08:15.817536');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (66, 1, 1, 7886.95, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (67, 1, 1, 9045.37, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (68, 2, 2, -1909.78, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (69, 2, 2, -1973.18, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (70, 6, 6, 8686.57, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (71, 6, 6, 7944.70, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (72, 7, 7, -1480.97, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (73, 7, 7, -2390.93, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (74, 11, 17, 9892.40, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (75, 11, 17, 8790.90, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (76, 2, 18, 8187.90, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (77, 2, 18, 5517.10, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (78, 8, 19, -1225.85, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (79, 8, 19, -1803.49, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (80, 10, 20, 5834.99, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (81, 10, 20, 9721.07, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (82, 12, 21, 9344.13, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (83, 12, 21, 5136.06, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (84, 12, 22, -2965.82, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (85, 12, 22, -2884.77, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (86, 10, 23, -2058.69, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (87, 10, 23, -2046.96, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (88, 8, 24, 6000.71, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (89, 8, 24, 9625.76, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (90, 6, 25, -2799.74, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (91, 6, 25, -2941.99, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (92, 11, 26, -2690.89, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (93, 11, 26, -2673.43, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (94, 14, 27, 7355.36, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (95, 14, 27, 8801.22, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (96, 13, 28, -2715.76, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (97, 13, 28, -2888.52, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (98, 1, 29, -2392.60, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (99, 1, 29, -1653.64, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (100, 5, 30, -1734.48, '2025-05-15', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (101, 5, 30, -1034.80, '2025-05-05', 'Expense for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (102, 3, 31, 5898.56, '2025-05-15', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');
INSERT INTO finance.finances (finance_id, user_id, category_id, amount, transaction_date, note, created_at, updated_at) VALUES (103, 3, 31, 9471.04, '2025-05-05', 'Income for May 2025', '2025-05-13 19:09:04.924032', '2025-05-13 19:09:04.924032');


--
-- TOC entry 5141 (class 0 OID 26711)
-- Dependencies: 232
-- Data for Name: habit_categories; Type: TABLE DATA; Schema: habits; Owner: postgres
--

INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (1, 1, 'Sports', '2025-05-13 15:52:43.665677', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (2, 2, 'Self-development', '2025-05-13 23:56:54.113403', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (3, 3, 'Health', '2025-05-13 10:30:26.973926', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (4, 4, 'Household chores', '2025-05-13 01:45:37.207153', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (5, 5, 'Handicraft', '2025-05-13 21:08:37.227885', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (6, 6, 'Meditation', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (7, 7, 'Reading', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (8, 8, 'Walks', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (9, 9, 'Language learning', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (10, 10, 'Planning', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_categories (category_id, user_id, name, created_at, updated_at) VALUES (11, 11, 'Фитнес', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');



--
-- TOC entry 5162 (class 0 OID 27718)
-- Dependencies: 255
-- Data for Name: habit_frequencies; Type: TABLE DATA; Schema: habits; Owner: postgres
--

INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (1, 'Daily', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (2, 'Every two days', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (3, 'Weekly', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (4, 'Monthly', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (5, 'Every 3 days', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (6, 'Every 5 days', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (7, 'Twice a week', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (8, 'Every two weeks', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (9, 'Quarterly', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (10, 'Semiannually', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (11, 'Annually', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (12, 'Weekdays', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (13, 'Weekends', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (14, 'As needed', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_frequencies (frequency_id, name, created_at) VALUES (15, 'Occasionally', '2025-05-13 12:24:28.911238');


--
-- TOC entry 5145 (class 0 OID 26744)
-- Dependencies: 236
-- Data for Name: habit_logs; Type: TABLE DATA; Schema: habits; Owner: postgres
--

INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (1, 1, '2025-04-01', true, '30 minutes', '2025-04-01 00:00:35.984369', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (2, 2, '2025-04-15', true, '20 pages', '2025-04-15 00:00:31.283756', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (3, 3, '2025-05-01', false, 'Forgot', '2025-05-01 00:00:05.226033', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (4, 4, '2025-04-20', true, 'Watered all plants', '2025-04-20 00:00:14.842872', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (5, 5, '2025-05-01', true, 'Sweater almost ready', '2025-05-01 00:00:31.905121', '2025-05-13 01:08:12.8578');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (6, 6, '2025-05-06', true, '10 minutes in the morning', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (7, 7, '2025-05-07', false, 'Didn’t have time', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (8, 8, '2025-05-08', true, 'Walk in the park', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (9, 9, '2025-05-09', true, 'Learned 50 words', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (10, 10, '2025-05-10', true, 'Day plan ready', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (11, 11, '2025-05-11', false, 'Missed workout', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (12, 12, '2025-05-12', true, 'Cooked pasta', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (13, 13, '2025-05-13', true, 'Drew a sketch', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (14, 14, '2025-05-14', true, 'Cleaning completed', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
INSERT INTO habits.habit_logs (log_id, habit_id, log_date, is_completed, note, created_at, updated_at) VALUES (15, 15, '2025-05-15', false, 'Didn’t start the course', '2025-05-13 12:24:28.911238', '2025-05-13 12:24:28.911238');
--
-- TOC entry 5163 (class 0 OID 27726)
-- Dependencies: 256
-- Data for Name: user_roles; Type: TABLE DATA; Schema: user; Owner: postgres
--

INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (1, 'Administrator', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (2, 'User', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (3, 'Moderator', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (4, 'Guest', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (5, 'Editor', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (6, 'Analyst', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (7, 'Tester', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (8, 'Developer', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (9, 'Manager', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (10, 'Designer', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (11, 'Content Manager', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (12, 'Marketer', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (13, 'Database Administrator', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (14, 'System Administrator', '2025-05-13 12:24:28.911238');
INSERT INTO "user".user_roles (role_id, name, created_at) VALUES (15, 'Support', '2025-05-13 12:24:28.911238');


--
-- TOC entry 5131 (class 0 OID 26496)
-- Dependencies: 222
-- Data for Name: users; Type: TABLE DATA; Schema: user; Owner: postgres
--

INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (1, 'arjun_sharma', 'arjun@example.com', 'Arjun', 'Sharma', '2025-05-13 12:24:28.911238', 1);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (2, 'priya_verma', 'priya@example.com', 'Priya', 'Verma', '2025-05-13 12:24:28.911238', 2);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (3, 'akash_singh', 'akash@example.com', 'Akash', 'Singh', '2025-05-13 12:24:28.911238', 2);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (4, 'sneha_kapoor', 'sneha@example.com', 'Sneha', 'Kapoor', '2025-05-13 12:24:28.911238', 2);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (5, 'rohan_mehta', 'rohan@example.com', 'Rohan', 'Mehta', '2025-05-13 12:24:28.911238', 2);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (6, 'ananya_iyer', 'ananya@example.com', 'Ananya', 'Iyer', '2025-05-13 12:24:28.911238', 2);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (7, 'vivaan_reddy', 'vivaan@example.com', 'Vivaan', 'Reddy', '2025-05-13 12:24:28.911238', 3);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (8, 'kavya_patel', 'kavya@example.com', 'Kavya', 'Patel', '2025-05-13 12:24:28.911238', 2);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (9, 'rahul_nair', 'rahul@example.com', 'Rahul', 'Nair', '2025-05-13 12:24:28.911238', 4);
INSERT INTO "user".users (user_id, username, email, first_name, last_name, updated_at, role_id) VALUES (10, 'neha_gupta', 'neha@example.com', 'Neha', 'Gupta', '2025-05-13 12:24:28.911238', 2);    

--
-- TOC entry 5347 (class 0 OID 0)
-- Dependencies: 239
-- Name: course_topics_topic_id_seq; Type: SEQUENCE SET; Schema: course; Owner: postgres
--

SELECT pg_catalog.setval('course.course_topics_topic_id_seq', 2, true);


--
-- TOC entry 5348 (class 0 OID 0)
-- Dependencies: 237
-- Name: courses_course_id_seq; Type: SEQUENCE SET; Schema: course; Owner: postgres
--

SELECT pg_catalog.setval('course.courses_course_id_seq', 50, true);


--
-- TOC entry 5349 (class 0 OID 0)
-- Dependencies: 223
-- Name: finance_categories_category_id_seq; Type: SEQUENCE SET; Schema: finance; Owner: postgres
--

SELECT pg_catalog.setval('finance.finance_categories_category_id_seq', 122, true);


--
-- TOC entry 5350 (class 0 OID 0)
-- Dependencies: 225
-- Name: finances_finance_id_seq; Type: SEQUENCE SET; Schema: finance; Owner: postgres
--

SELECT pg_catalog.setval('finance.finances_finance_id_seq', 214, true);


--
-- TOC entry 5351 (class 0 OID 0)
-- Dependencies: 231
-- Name: habit_categories_category_id_seq; Type: SEQUENCE SET; Schema: habits; Owner: postgres
--

SELECT pg_catalog.setval('habits.habit_categories_category_id_seq', 15, true);


--
-- TOC entry 5352 (class 0 OID 0)
-- Dependencies: 235
-- Name: habit_logs_log_id_seq; Type: SEQUENCE SET; Schema: habits; Owner: postgres
--

SELECT pg_catalog.setval('habits.habit_logs_log_id_seq', 15, true);


--
-- TOC entry 5353 (class 0 OID 0)
-- Dependencies: 233
-- Name: habits_habit_id_seq; Type: SEQUENCE SET; Schema: habits; Owner: postgres
--

SELECT pg_catalog.setval('habits.habits_habit_id_seq', 15, true);


--
-- TOC entry 5354 (class 0 OID 0)
-- Dependencies: 227
-- Name: todo_categories_category_id_seq; Type: SEQUENCE SET; Schema: todo; Owner: postgres
--

SELECT pg_catalog.setval('todo.todo_categories_category_id_seq', 15, true);


--
-- TOC entry 5355 (class 0 OID 0)
-- Dependencies: 229
-- Name: todos_todo_id_seq; Type: SEQUENCE SET; Schema: todo; Owner: postgres
--

SELECT pg_catalog.setval('todo.todos_todo_id_seq', 15, true);


--
-- TOC entry 5356 (class 0 OID 0)
-- Dependencies: 258
-- Name: expense_categories_category_id_seq; Type: SEQUENCE SET; Schema: trips; Owner: postgres
--

SELECT pg_catalog.setval('trips.expense_categories_category_id_seq', 15, true);


--
-- TOC entry 5357 (class 0 OID 0)
-- Dependencies: 246
-- Name: trip_expenses_expense_id_seq; Type: SEQUENCE SET; Schema: trips; Owner: postgres
--

SELECT pg_catalog.setval('trips.trip_expenses_expense_id_seq', 15, true);


--
-- TOC entry 5358 (class 0 OID 0)
-- Dependencies: 243
-- Name: trip_routes_route_id_seq; Type: SEQUENCE SET; Schema: trips; Owner: postgres
--

SELECT pg_catalog.setval('trips.trip_routes_route_id_seq', 15, true);


--
-- TOC entry 5359 (class 0 OID 0)
-- Dependencies: 241
-- Name: trips_trip_id_seq; Type: SEQUENCE SET; Schema: trips; Owner: postgres
--

SELECT pg_catalog.setval('trips.trips_trip_id_seq', 15, true);


--
-- TOC entry 5360 (class 0 OID 0)
-- Dependencies: 221
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: user; Owner: postgres
--

SELECT pg_catalog.setval('"user".users_user_id_seq', 5, true);


--
-- TOC entry 4935 (class 2606 OID 27699)
-- Name: course_statuses course_statuses_pkey; Type: CONSTRAINT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.course_statuses
    ADD CONSTRAINT course_statuses_pkey PRIMARY KEY (status_id);


--
-- TOC entry 4913 (class 2606 OID 26816)
-- Name: course_topics course_topics_pkey; Type: CONSTRAINT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.course_topics
    ADD CONSTRAINT course_topics_pkey PRIMARY KEY (topic_id);


--
-- TOC entry 4908 (class 2606 OID 26801)
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (course_id);


--
-- TOC entry 4910 (class 2606 OID 26921)
-- Name: courses courses_unique; Type: CONSTRAINT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.courses
    ADD CONSTRAINT courses_unique UNIQUE (user_id, title);


--
-- TOC entry 4874 (class 2606 OID 26518)
-- Name: finance_categories finance_categories_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finance_categories
    ADD CONSTRAINT finance_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4929 (class 2606 OID 27226)
-- Name: finance_types finance_types_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finance_types
    ADD CONSTRAINT finance_types_pkey PRIMARY KEY (type_id);


--
-- TOC entry 4876 (class 2606 OID 26535)
-- Name: finances finances_pkey; Type: CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finances
    ADD CONSTRAINT finances_pkey PRIMARY KEY (finance_id);


--
-- TOC entry 4891 (class 2606 OID 26716)
-- Name: habit_categories habit_categories_pkey; Type: CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_categories
    ADD CONSTRAINT habit_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4893 (class 2606 OID 26718)
-- Name: habit_categories habit_categories_unique; Type: CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_categories
    ADD CONSTRAINT habit_categories_unique UNIQUE (user_id, name);


--
-- TOC entry 4941 (class 2606 OID 27723)
-- Name: habit_frequencies habit_frequencies_pkey; Type: CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_frequencies
    ADD CONSTRAINT habit_frequencies_pkey PRIMARY KEY (frequency_id);


--
-- TOC entry 4901 (class 2606 OID 26752)
-- Name: habit_logs habit_logs_pkey; Type: CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_logs
    ADD CONSTRAINT habit_logs_pkey PRIMARY KEY (log_id);


--
-- TOC entry 4896 (class 2606 OID 26732)
-- Name: habits habits_pkey; Type: CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT habits_pkey PRIMARY KEY (habit_id);


--
-- TOC entry 4898 (class 2606 OID 26923)
-- Name: habits habits_unique; Type: CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT habits_unique UNIQUE (user_id, name);


--
-- TOC entry 4906 (class 2606 OID 26754)
-- Name: habit_logs unique_habit_log; Type: CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_logs
    ADD CONSTRAINT unique_habit_log UNIQUE (habit_id, log_date);


--
-- TOC entry 4933 (class 2606 OID 27691)
-- Name: task_priorities task_priorities_pkey; Type: CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.task_priorities
    ADD CONSTRAINT task_priorities_pkey PRIMARY KEY (priority_id);


--
-- TOC entry 4931 (class 2606 OID 27683)
-- Name: task_statuses task_statuses_pkey; Type: CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.task_statuses
    ADD CONSTRAINT task_statuses_pkey PRIMARY KEY (status_id);


--
-- TOC entry 4881 (class 2606 OID 26680)
-- Name: todo_categories todo_categories_pkey; Type: CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todo_categories
    ADD CONSTRAINT todo_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4887 (class 2606 OID 26697)
-- Name: todos todos_pkey; Type: CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT todos_pkey PRIMARY KEY (todo_id);


--
-- TOC entry 4889 (class 2606 OID 27782)
-- Name: todos todos_unique; Type: CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT todos_unique UNIQUE (user_id, category_id, task);


--
-- TOC entry 4939 (class 2606 OID 27715)
-- Name: expense_categories expense_categories_pkey; Type: CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.expense_categories
    ADD CONSTRAINT expense_categories_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4937 (class 2606 OID 27707)
-- Name: transportation_types transportation_types_pkey; Type: CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.transportation_types
    ADD CONSTRAINT transportation_types_pkey PRIMARY KEY (type_id);


--
-- TOC entry 4927 (class 2606 OID 26887)
-- Name: trip_expenses trip_expenses_pkey; Type: CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_expenses
    ADD CONSTRAINT trip_expenses_pkey PRIMARY KEY (expense_id);


--
-- TOC entry 4922 (class 2606 OID 26865)
-- Name: trip_routes trip_routes_pkey; Type: CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_routes
    ADD CONSTRAINT trip_routes_pkey PRIMARY KEY (route_id);


--
-- TOC entry 4919 (class 2606 OID 26852)
-- Name: trips trips_pkey; Type: CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trips
    ADD CONSTRAINT trips_pkey PRIMARY KEY (trip_id);


--
-- TOC entry 4924 (class 2606 OID 26867)
-- Name: trip_routes unique_route_order; Type: CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_routes
    ADD CONSTRAINT unique_route_order UNIQUE (trip_id, location_order);


--
-- TOC entry 4943 (class 2606 OID 27731)
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: user; Owner: postgres
--

ALTER TABLE ONLY "user".user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (role_id);


--
-- TOC entry 4868 (class 2606 OID 26510)
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: user; Owner: postgres
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- TOC entry 4870 (class 2606 OID 26506)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: user; Owner: postgres
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4872 (class 2606 OID 26508)
-- Name: users users_username_unique; Type: CONSTRAINT; Schema: user; Owner: postgres
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT users_username_unique UNIQUE (username);


--
-- TOC entry 4914 (class 1259 OID 27774)
-- Name: idx_course_topics_completed_date; Type: INDEX; Schema: course; Owner: postgres
--

CREATE INDEX idx_course_topics_completed_date ON course.course_topics USING btree (completed_date);


--
-- TOC entry 4915 (class 1259 OID 26898)
-- Name: idx_course_topics_course_id; Type: INDEX; Schema: course; Owner: postgres
--

CREATE INDEX idx_course_topics_course_id ON course.course_topics USING btree (course_id);


--
-- TOC entry 4916 (class 1259 OID 27822)
-- Name: idx_course_topics_grade; Type: INDEX; Schema: course; Owner: postgres
--

CREATE INDEX idx_course_topics_grade ON course.course_topics USING btree (grade);


--
-- TOC entry 4911 (class 1259 OID 26917)
-- Name: idx_courses_user_id; Type: INDEX; Schema: course; Owner: postgres
--

CREATE INDEX idx_courses_user_id ON course.courses USING btree (user_id);


--
-- TOC entry 4877 (class 1259 OID 26894)
-- Name: idx_finances_transaction_date; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_finances_transaction_date ON finance.finances USING btree (transaction_date);


--
-- TOC entry 4878 (class 1259 OID 26893)
-- Name: idx_finances_user_id; Type: INDEX; Schema: finance; Owner: postgres
--

CREATE INDEX idx_finances_user_id ON finance.finances USING btree (user_id);


--
-- TOC entry 4894 (class 1259 OID 26981)
-- Name: idx_habit_categories_user_id; Type: INDEX; Schema: habits; Owner: postgres
--

CREATE INDEX idx_habit_categories_user_id ON habits.habit_categories USING btree (user_id);


--
-- TOC entry 4902 (class 1259 OID 26897)
-- Name: idx_habit_logs_habit_id; Type: INDEX; Schema: habits; Owner: postgres
--

CREATE INDEX idx_habit_logs_habit_id ON habits.habit_logs USING btree (habit_id);


--
-- TOC entry 4903 (class 1259 OID 27780)
-- Name: idx_habit_logs_is_completed; Type: INDEX; Schema: habits; Owner: postgres
--

CREATE INDEX idx_habit_logs_is_completed ON habits.habit_logs USING btree (is_completed);


--
-- TOC entry 4904 (class 1259 OID 26919)
-- Name: idx_habit_logs_log_date; Type: INDEX; Schema: habits; Owner: postgres
--

CREATE INDEX idx_habit_logs_log_date ON habits.habit_logs USING btree (log_date);


--
-- TOC entry 4899 (class 1259 OID 26918)
-- Name: idx_habits_user_id; Type: INDEX; Schema: habits; Owner: postgres
--

CREATE INDEX idx_habits_user_id ON habits.habits USING btree (user_id);


--
-- TOC entry 4879 (class 1259 OID 26980)
-- Name: idx_todo_categories_user_id; Type: INDEX; Schema: todo; Owner: postgres
--

CREATE INDEX idx_todo_categories_user_id ON todo.todo_categories USING btree (user_id);


--
-- TOC entry 4882 (class 1259 OID 27773)
-- Name: idx_todos_completed_date; Type: INDEX; Schema: todo; Owner: postgres
--

CREATE INDEX idx_todos_completed_date ON todo.todos USING btree (completed_date);


--
-- TOC entry 4883 (class 1259 OID 26896)
-- Name: idx_todos_due_date; Type: INDEX; Schema: todo; Owner: postgres
--

CREATE INDEX idx_todos_due_date ON todo.todos USING btree (due_date);


--
-- TOC entry 4884 (class 1259 OID 27772)
-- Name: idx_todos_is_completed; Type: INDEX; Schema: todo; Owner: postgres
--

CREATE INDEX idx_todos_is_completed ON todo.todos USING btree (is_completed);


--
-- TOC entry 4885 (class 1259 OID 26895)
-- Name: idx_todos_user_id; Type: INDEX; Schema: todo; Owner: postgres
--

CREATE INDEX idx_todos_user_id ON todo.todos USING btree (user_id);


--
-- TOC entry 4925 (class 1259 OID 26916)
-- Name: idx_trip_expenses_route_id; Type: INDEX; Schema: trips; Owner: postgres
--

CREATE INDEX idx_trip_expenses_route_id ON trips.trip_expenses USING btree (route_id);


--
-- TOC entry 4920 (class 1259 OID 26915)
-- Name: idx_trip_routes_trip_id; Type: INDEX; Schema: trips; Owner: postgres
--

CREATE INDEX idx_trip_routes_trip_id ON trips.trip_routes USING btree (trip_id);


--
-- TOC entry 4917 (class 1259 OID 26979)
-- Name: idx_trips_user_id; Type: INDEX; Schema: trips; Owner: postgres
--

CREATE INDEX idx_trips_user_id ON trips.trips USING btree (user_id);


--
-- TOC entry 4866 (class 1259 OID 26977)
-- Name: idx_users_user_id; Type: INDEX; Schema: user; Owner: postgres
--

CREATE INDEX idx_users_user_id ON "user".users USING btree (user_id);


--
-- TOC entry 4978 (class 2620 OID 28730)
-- Name: course_topics course_topics_status_trigger; Type: TRIGGER; Schema: course; Owner: postgres
--

CREATE TRIGGER course_topics_status_trigger AFTER INSERT OR UPDATE OF completed_date ON course.course_topics FOR EACH ROW EXECUTE FUNCTION course.update_course_status();


--
-- TOC entry 4979 (class 2620 OID 26957)
-- Name: course_topics course_topics_updated_at_trigger; Type: TRIGGER; Schema: course; Owner: postgres
--

CREATE TRIGGER course_topics_updated_at_trigger BEFORE UPDATE ON course.course_topics FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4977 (class 2620 OID 26954)
-- Name: courses courses_updated_at_trigger; Type: TRIGGER; Schema: course; Owner: postgres
--

CREATE TRIGGER courses_updated_at_trigger BEFORE UPDATE ON course.courses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4968 (class 2620 OID 26930)
-- Name: finance_categories finance_categories_updated_at_trigger; Type: TRIGGER; Schema: finance; Owner: postgres
--

CREATE TRIGGER finance_categories_updated_at_trigger BEFORE UPDATE ON finance.finance_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4969 (class 2620 OID 27771)
-- Name: finances finances_amount_trigger; Type: TRIGGER; Schema: finance; Owner: postgres
--

CREATE TRIGGER finances_amount_trigger BEFORE INSERT OR UPDATE ON finance.finances FOR EACH ROW EXECUTE FUNCTION finance.check_finance_amount();


--
-- TOC entry 4970 (class 2620 OID 26933)
-- Name: finances finances_updated_at_trigger; Type: TRIGGER; Schema: finance; Owner: postgres
--

CREATE TRIGGER finances_updated_at_trigger BEFORE UPDATE ON finance.finances FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4974 (class 2620 OID 26945)
-- Name: habit_categories habit_categories_updated_at_trigger; Type: TRIGGER; Schema: habits; Owner: postgres
--

CREATE TRIGGER habit_categories_updated_at_trigger BEFORE UPDATE ON habits.habit_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4976 (class 2620 OID 26951)
-- Name: habit_logs habit_logs_updated_at_trigger; Type: TRIGGER; Schema: habits; Owner: postgres
--

CREATE TRIGGER habit_logs_updated_at_trigger BEFORE UPDATE ON habits.habit_logs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4975 (class 2620 OID 26948)
-- Name: habits habits_updated_at_trigger; Type: TRIGGER; Schema: habits; Owner: postgres
--

CREATE TRIGGER habits_updated_at_trigger BEFORE UPDATE ON habits.habits FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4971 (class 2620 OID 26939)
-- Name: todo_categories todo_categories_updated_at_trigger; Type: TRIGGER; Schema: todo; Owner: postgres
--

CREATE TRIGGER todo_categories_updated_at_trigger BEFORE UPDATE ON todo.todo_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4972 (class 2620 OID 26709)
-- Name: todos todos_completed_date_trigger; Type: TRIGGER; Schema: todo; Owner: postgres
--

CREATE TRIGGER todos_completed_date_trigger BEFORE UPDATE ON todo.todos FOR EACH ROW EXECUTE FUNCTION todo.set_completed_date();


--
-- TOC entry 4973 (class 2620 OID 26942)
-- Name: todos todos_updated_at_trigger; Type: TRIGGER; Schema: todo; Owner: postgres
--

CREATE TRIGGER todos_updated_at_trigger BEFORE UPDATE ON todo.todos FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4982 (class 2620 OID 26966)
-- Name: trip_expenses trip_expenses_updated_at_trigger; Type: TRIGGER; Schema: trips; Owner: postgres
--

CREATE TRIGGER trip_expenses_updated_at_trigger BEFORE UPDATE ON trips.trip_expenses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4981 (class 2620 OID 26963)
-- Name: trip_routes trip_routes_updated_at_trigger; Type: TRIGGER; Schema: trips; Owner: postgres
--

CREATE TRIGGER trip_routes_updated_at_trigger BEFORE UPDATE ON trips.trip_routes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4980 (class 2620 OID 26960)
-- Name: trips trips_updated_at_trigger; Type: TRIGGER; Schema: trips; Owner: postgres
--

CREATE TRIGGER trips_updated_at_trigger BEFORE UPDATE ON trips.trips FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4967 (class 2620 OID 26927)
-- Name: users users_updated_at_trigger; Type: TRIGGER; Schema: user; Owner: postgres
--

CREATE TRIGGER users_updated_at_trigger BEFORE UPDATE ON "user".users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- TOC entry 4960 (class 2606 OID 27059)
-- Name: course_topics course_topics_course_id_fkey; Type: FK CONSTRAINT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.course_topics
    ADD CONSTRAINT course_topics_course_id_fkey FOREIGN KEY (course_id) REFERENCES course.courses(course_id) ON DELETE CASCADE;


--
-- TOC entry 4961 (class 2606 OID 27054)
-- Name: course_topics course_topics_user_id_fkey; Type: FK CONSTRAINT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.course_topics
    ADD CONSTRAINT course_topics_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4958 (class 2606 OID 27049)
-- Name: courses courses_user_id_fkey; Type: FK CONSTRAINT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.courses
    ADD CONSTRAINT courses_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4959 (class 2606 OID 27739)
-- Name: courses fk_courses_status; Type: FK CONSTRAINT; Schema: course; Owner: postgres
--

ALTER TABLE ONLY course.courses
    ADD CONSTRAINT fk_courses_status FOREIGN KEY (status_id) REFERENCES course.course_statuses(status_id);


--
-- TOC entry 4945 (class 2606 OID 26994)
-- Name: finance_categories finance_categories_user_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finance_categories
    ADD CONSTRAINT finance_categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4947 (class 2606 OID 27004)
-- Name: finances finances_category_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finances
    ADD CONSTRAINT finances_category_id_fkey FOREIGN KEY (category_id) REFERENCES finance.finance_categories(category_id) ON DELETE CASCADE;


--
-- TOC entry 4948 (class 2606 OID 26999)
-- Name: finances finances_user_id_fkey; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finances
    ADD CONSTRAINT finances_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4946 (class 2606 OID 27229)
-- Name: finance_categories fk_finance_categories_type; Type: FK CONSTRAINT; Schema: finance; Owner: postgres
--

ALTER TABLE ONLY finance.finance_categories
    ADD CONSTRAINT fk_finance_categories_type FOREIGN KEY (type_id) REFERENCES finance.finance_types(type_id);


--
-- TOC entry 4954 (class 2606 OID 27759)
-- Name: habits fk_habits_frequency; Type: FK CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT fk_habits_frequency FOREIGN KEY (frequency_id) REFERENCES habits.habit_frequencies(frequency_id);


--
-- TOC entry 4953 (class 2606 OID 27029)
-- Name: habit_categories habit_categories_user_id_fkey; Type: FK CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_categories
    ADD CONSTRAINT habit_categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4957 (class 2606 OID 27044)
-- Name: habit_logs habit_logs_habit_id_fkey; Type: FK CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habit_logs
    ADD CONSTRAINT habit_logs_habit_id_fkey FOREIGN KEY (habit_id) REFERENCES habits.habits(habit_id) ON DELETE CASCADE;


--
-- TOC entry 4955 (class 2606 OID 27039)
-- Name: habits habits_category_id_fkey; Type: FK CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT habits_category_id_fkey FOREIGN KEY (category_id) REFERENCES habits.habit_categories(category_id) ON DELETE CASCADE;


--
-- TOC entry 4956 (class 2606 OID 27034)
-- Name: habits habits_user_id_fkey; Type: FK CONSTRAINT; Schema: habits; Owner: postgres
--

ALTER TABLE ONLY habits.habits
    ADD CONSTRAINT habits_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4950 (class 2606 OID 27734)
-- Name: todos fk_todos_task_priority; Type: FK CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT fk_todos_task_priority FOREIGN KEY (task_priority_id) REFERENCES todo.task_priorities(priority_id);


--
-- TOC entry 4949 (class 2606 OID 27014)
-- Name: todo_categories todo_categories_user_id_fkey; Type: FK CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todo_categories
    ADD CONSTRAINT todo_categories_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4951 (class 2606 OID 27024)
-- Name: todos todos_category_id_fkey; Type: FK CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT todos_category_id_fkey FOREIGN KEY (category_id) REFERENCES todo.todo_categories(category_id) ON DELETE CASCADE;


--
-- TOC entry 4952 (class 2606 OID 27019)
-- Name: todos todos_user_id_fkey; Type: FK CONSTRAINT; Schema: todo; Owner: postgres
--

ALTER TABLE ONLY todo.todos
    ADD CONSTRAINT todos_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4965 (class 2606 OID 27754)
-- Name: trip_expenses fk_trip_expenses_category; Type: FK CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_expenses
    ADD CONSTRAINT fk_trip_expenses_category FOREIGN KEY (expense_category_id) REFERENCES trips.expense_categories(category_id);


--
-- TOC entry 4963 (class 2606 OID 27749)
-- Name: trip_routes fk_trip_routes_transportation_type; Type: FK CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_routes
    ADD CONSTRAINT fk_trip_routes_transportation_type FOREIGN KEY (transportation_type_id) REFERENCES trips.transportation_types(type_id);


--
-- TOC entry 4966 (class 2606 OID 27074)
-- Name: trip_expenses trip_expenses_route_id_fkey; Type: FK CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_expenses
    ADD CONSTRAINT trip_expenses_route_id_fkey FOREIGN KEY (route_id) REFERENCES trips.trip_routes(route_id) ON DELETE CASCADE;


--
-- TOC entry 4964 (class 2606 OID 27069)
-- Name: trip_routes trip_routes_trip_id_fkey; Type: FK CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trip_routes
    ADD CONSTRAINT trip_routes_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES trips.trips(trip_id) ON DELETE CASCADE;


--
-- TOC entry 4962 (class 2606 OID 27064)
-- Name: trips trips_user_id_fkey; Type: FK CONSTRAINT; Schema: trips; Owner: postgres
--

ALTER TABLE ONLY trips.trips
    ADD CONSTRAINT trips_user_id_fkey FOREIGN KEY (user_id) REFERENCES "user".users(user_id) ON DELETE CASCADE;


--
-- TOC entry 4944 (class 2606 OID 27765)
-- Name: users fk_users_role; Type: FK CONSTRAINT; Schema: user; Owner: postgres
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES "user".user_roles(role_id);


-- Completed on 2025-06-29 15:04:56

--
-- PostgreSQL database dump complete
--

