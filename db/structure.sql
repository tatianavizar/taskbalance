\restrict Ql9pAnvL60hORjPoFeqKdF29BRgMQrGaIXYPrHY2PaVliad2opolt8tLRai3h58

-- Dumped from database version 16.14 (Homebrew)
-- Dumped by pg_dump version 16.14 (Homebrew)

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
-- Name: admin_actions_append_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_actions_append_only() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'admin_actions is append-only (% refused)', TG_OP;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: absence_answers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.absence_answers (
    id bigint NOT NULL,
    absence_inquiry_id bigint NOT NULL,
    household_member_id bigint NOT NULL,
    answer character varying NOT NULL,
    answered_at timestamp(6) without time zone NOT NULL,
    member_pause_id bigint,
    original_answer character varying,
    corrected_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT absence_answers_answer_values CHECK (((answer)::text = ANY ((ARRAY['yes'::character varying, 'no'::character varying])::text[])))
);


--
-- Name: absence_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.absence_answers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: absence_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.absence_answers_id_seq OWNED BY public.absence_answers.id;


--
-- Name: absence_inquiries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.absence_inquiries (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    household_member_id bigint NOT NULL,
    first_week_start date NOT NULL,
    last_week_start date NOT NULL,
    deadline_at timestamp(6) without time zone NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    resolved_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: absence_inquiries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.absence_inquiries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: absence_inquiries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.absence_inquiries_id_seq OWNED BY public.absence_inquiries.id;


--
-- Name: admin_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_actions (
    id bigint NOT NULL,
    admin_user_id bigint,
    admin_email character varying NOT NULL,
    action character varying NOT NULL,
    record_type character varying,
    record_id bigint,
    detail jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: admin_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_actions_id_seq OWNED BY public.admin_actions.id;


--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    encrypted_password character varying NOT NULL,
    otp_secret text,
    consumed_timestep integer,
    otp_required_for_login boolean DEFAULT false NOT NULL,
    failed_attempts integer DEFAULT 0 NOT NULL,
    locked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    session_version integer DEFAULT 0 NOT NULL,
    enrolment_nonce character varying,
    deactivated_at timestamp(6) without time zone
);


--
-- Name: admin_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_users_id_seq OWNED BY public.admin_users.id;


--
-- Name: approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approvals (
    id bigint NOT NULL,
    approvable_type character varying NOT NULL,
    approvable_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.approvals_id_seq OWNED BY public.approvals.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chore_assignees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chore_assignees (
    id bigint NOT NULL,
    chore_id bigint NOT NULL,
    user_id bigint,
    invitation_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chore_assignees_one_assignee CHECK ((num_nonnulls(user_id, invitation_id) = 1))
);


--
-- Name: chore_assignees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chore_assignees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chore_assignees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chore_assignees_id_seq OWNED BY public.chore_assignees.id;


--
-- Name: chore_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chore_logs (
    id bigint NOT NULL,
    chore_id bigint,
    household_id bigint,
    user_id bigint NOT NULL,
    mental_load boolean NOT NULL,
    execution_load boolean NOT NULL,
    time_spent integer NOT NULL,
    completed_at timestamp(6) without time zone NOT NULL,
    chore_name character varying,
    category character varying,
    occurrence_id bigint,
    idempotency_key character varying,
    off_split boolean DEFAULT false NOT NULL
);


--
-- Name: chore_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chore_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chore_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chore_logs_id_seq OWNED BY public.chore_logs.id;


--
-- Name: chore_occurrences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chore_occurrences (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    chore_id bigint NOT NULL,
    week_start date NOT NULL,
    slot integer NOT NULL,
    due_on date NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chore_occurrences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chore_occurrences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chore_occurrences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chore_occurrences_id_seq OWNED BY public.chore_occurrences.id;


--
-- Name: chore_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chore_preferences (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    chore_id bigint NOT NULL,
    choice character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chore_preferences_choice CHECK (((choice)::text = ANY ((ARRAY['like'::character varying, 'neutral'::character varying, 'dislike'::character varying])::text[])))
);


--
-- Name: chore_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chore_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chore_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chore_preferences_id_seq OWNED BY public.chore_preferences.id;


--
-- Name: chores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chores (
    id bigint NOT NULL,
    task_id bigint,
    household_id bigint NOT NULL,
    status integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    mental_load boolean DEFAULT false NOT NULL,
    execution_load boolean DEFAULT false NOT NULL,
    time_required integer,
    due_date date,
    custom_name character varying,
    category character varying,
    frequency integer DEFAULT 1 NOT NULL,
    times_per_period integer DEFAULT 1 NOT NULL,
    anchor_on date,
    created_by_id bigint,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT chores_times_per_period_positive CHECK ((times_per_period >= 1))
);


--
-- Name: chores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chores_id_seq OWNED BY public.chores.id;


--
-- Name: engine_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.engine_events (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    name character varying NOT NULL,
    subject_type character varying,
    subject_id bigint,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    delivered_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: engine_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.engine_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: engine_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.engine_events_id_seq OWNED BY public.engine_events.id;


--
-- Name: household_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.household_members (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    household_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    color character varying,
    monogram character varying,
    monogram_customized boolean DEFAULT false NOT NULL,
    empty_weeks_streak integer DEFAULT 0 NOT NULL
);


--
-- Name: household_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.household_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: household_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.household_members_id_seq OWNED BY public.household_members.id;


--
-- Name: household_weeks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.household_weeks (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    week_start date NOT NULL,
    time_zone character varying NOT NULL,
    status character varying DEFAULT 'provisional'::character varying NOT NULL,
    outcome character varying NOT NULL,
    neutral_reason character varying,
    fair_share integer,
    mental_total integer DEFAULT 0 NOT NULL,
    execution_total integer DEFAULT 0 NOT NULL,
    minutes_total integer DEFAULT 0 NOT NULL,
    members jsonb DEFAULT '[]'::jsonb NOT NULL,
    pauses jsonb DEFAULT '[]'::jsonb NOT NULL,
    computed_at timestamp(6) without time zone NOT NULL,
    finalized_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: household_weeks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.household_weeks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: household_weeks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.household_weeks_id_seq OWNED BY public.household_weeks.id;


--
-- Name: households; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.households (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    time_zone character varying DEFAULT 'Europe/Paris'::character varying NOT NULL,
    level integer DEFAULT 0 NOT NULL,
    balanced_weeks_count integer DEFAULT 0 NOT NULL,
    state character varying DEFAULT 'solo'::character varying NOT NULL,
    silent_weeks_count integer DEFAULT 0 NOT NULL,
    blocked_at timestamp(6) without time zone,
    ultimate_reached_on date,
    setup_step character varying DEFAULT 'done'::character varying NOT NULL,
    weekly_proposal_enabled boolean DEFAULT true NOT NULL,
    gap_carry_over_enabled boolean DEFAULT true NOT NULL,
    auto_validate_splits boolean DEFAULT false NOT NULL,
    gap_folded_through date
);


--
-- Name: households_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.households_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: households_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.households_id_seq OWNED BY public.households.id;


--
-- Name: invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitations (
    id bigint NOT NULL,
    email character varying NOT NULL,
    household_id bigint NOT NULL,
    token character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    state character varying DEFAULT 'pending'::character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    last_sent_at timestamp(6) without time zone NOT NULL,
    resend_count integer DEFAULT 0 NOT NULL,
    accepted_at timestamp(6) without time zone,
    declined_at timestamp(6) without time zone,
    cancelled_at timestamp(6) without time zone,
    invitee_id bigint,
    inviter_id bigint,
    first_name character varying,
    color character varying,
    monogram character varying
);


--
-- Name: invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invitations_id_seq OWNED BY public.invitations.id;


--
-- Name: level_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.level_changes (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    household_week_id bigint,
    absence_inquiry_id bigint,
    from_level integer NOT NULL,
    to_level integer NOT NULL,
    balanced_weeks_count_before integer NOT NULL,
    balanced_weeks_count_after integer NOT NULL,
    reason character varying NOT NULL,
    week_start date,
    created_at timestamp(6) without time zone NOT NULL,
    cancelled_level_change_id bigint
);


--
-- Name: level_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.level_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: level_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.level_changes_id_seq OWNED BY public.level_changes.id;


--
-- Name: member_pauses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.member_pauses (
    id bigint NOT NULL,
    household_member_id bigint NOT NULL,
    declared_by_id bigint,
    starts_on date NOT NULL,
    ends_on date,
    reason character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT member_pauses_dates_ordered CHECK (((ends_on IS NULL) OR (ends_on >= starts_on)))
);


--
-- Name: member_pauses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.member_pauses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: member_pauses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_pauses_id_seq OWNED BY public.member_pauses.id;


--
-- Name: notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_preferences (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    event_type character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notification_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_preferences_id_seq OWNED BY public.notification_preferences.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    household_id bigint,
    kind character varying NOT NULL,
    event_type character varying NOT NULL,
    cap_class character varying,
    dedup_key character varying NOT NULL,
    facts jsonb DEFAULT '{}'::jsonb NOT NULL,
    channel character varying,
    suppressed_reason character varying,
    cap_week_start date,
    deliver_at timestamp(6) without time zone NOT NULL,
    dispatched_at timestamp(6) without time zone,
    read_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT notifications_sent_or_suppressed CHECK (((channel IS NULL) OR (suppressed_reason IS NULL)))
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: split_gap_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.split_gap_entries (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    user_id bigint,
    kind character varying NOT NULL,
    week_start date NOT NULL,
    amount numeric(8,3) NOT NULL,
    reset_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT split_gap_entries_kind CHECK (((kind)::text = ANY ((ARRAY['week'::character varying, 'reset'::character varying])::text[])))
);


--
-- Name: split_gap_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.split_gap_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: split_gap_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.split_gap_entries_id_seq OWNED BY public.split_gap_entries.id;


--
-- Name: split_setting_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.split_setting_changes (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    proposed_by_id bigint,
    changes_requested jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    applied_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT split_setting_changes_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'applied'::character varying, 'withdrawn'::character varying])::text[])))
);


--
-- Name: split_setting_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.split_setting_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: split_setting_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.split_setting_changes_id_seq OWNED BY public.split_setting_changes.id;


--
-- Name: task_handovers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.task_handovers (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    chore_id bigint NOT NULL,
    from_user_id bigint NOT NULL,
    to_user_id bigint NOT NULL,
    week_start date NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    responded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT task_handovers_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'refused'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT task_handovers_two_people CHECK ((from_user_id <> to_user_id))
);


--
-- Name: task_handovers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.task_handovers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: task_handovers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.task_handovers_id_seq OWNED BY public.task_handovers.id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id bigint NOT NULL,
    name character varying,
    time_required integer,
    priority integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    recurring boolean DEFAULT false NOT NULL,
    category character varying DEFAULT 'other'::character varying NOT NULL,
    key character varying NOT NULL,
    default_mental_load boolean DEFAULT false NOT NULL,
    default_execution_load boolean DEFAULT false NOT NULL,
    frequency integer DEFAULT 1 NOT NULL,
    times_per_period integer DEFAULT 1 NOT NULL,
    CONSTRAINT tasks_times_per_period_positive CHECK ((times_per_period >= 1))
);


--
-- Name: tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tasks_id_seq OWNED BY public.tasks.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    role integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    time_zone character varying DEFAULT 'Europe/Paris'::character varying NOT NULL,
    first_name character varying NOT NULL,
    confirmation_token character varying,
    confirmed_at timestamp(6) without time zone,
    confirmation_sent_at timestamp(6) without time zone,
    unconfirmed_email character varying,
    deleted_at timestamp(6) without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: week_corrections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.week_corrections (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    household_week_id bigint NOT NULL,
    member_pause_id bigint,
    user_id bigint,
    declared_by_id bigint,
    first_name character varying NOT NULL,
    declared_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: week_corrections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.week_corrections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: week_corrections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.week_corrections_id_seq OWNED BY public.week_corrections.id;


--
-- Name: week_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.week_plans (
    id bigint NOT NULL,
    household_id bigint NOT NULL,
    week_start date NOT NULL,
    kind character varying DEFAULT 'weekly'::character varying NOT NULL,
    status character varying NOT NULL,
    provisional boolean DEFAULT false NOT NULL,
    proposed_by_id bigint,
    proposed_at timestamp(6) without time zone,
    validated_at timestamp(6) without time zone,
    participants jsonb DEFAULT '[]'::jsonb NOT NULL,
    assignments jsonb DEFAULT '[]'::jsonb NOT NULL,
    shares jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    targets jsonb DEFAULT '{}'::jsonb NOT NULL,
    carry_gap boolean DEFAULT true NOT NULL,
    gap_waived_by_id bigint,
    CONSTRAINT week_plans_kind CHECK (((kind)::text = ANY ((ARRAY['starting'::character varying, 'weekly'::character varying])::text[]))),
    CONSTRAINT week_plans_status CHECK (((status)::text = ANY ((ARRAY['awaiting_proposal'::character varying, 'proposed'::character varying, 'validated'::character varying])::text[])))
);


--
-- Name: week_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.week_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: week_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.week_plans_id_seq OWNED BY public.week_plans.id;


--
-- Name: absence_answers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_answers ALTER COLUMN id SET DEFAULT nextval('public.absence_answers_id_seq'::regclass);


--
-- Name: absence_inquiries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_inquiries ALTER COLUMN id SET DEFAULT nextval('public.absence_inquiries_id_seq'::regclass);


--
-- Name: admin_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_actions ALTER COLUMN id SET DEFAULT nextval('public.admin_actions_id_seq'::regclass);


--
-- Name: admin_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users ALTER COLUMN id SET DEFAULT nextval('public.admin_users_id_seq'::regclass);


--
-- Name: approvals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals ALTER COLUMN id SET DEFAULT nextval('public.approvals_id_seq'::regclass);


--
-- Name: chore_assignees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_assignees ALTER COLUMN id SET DEFAULT nextval('public.chore_assignees_id_seq'::regclass);


--
-- Name: chore_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_logs ALTER COLUMN id SET DEFAULT nextval('public.chore_logs_id_seq'::regclass);


--
-- Name: chore_occurrences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_occurrences ALTER COLUMN id SET DEFAULT nextval('public.chore_occurrences_id_seq'::regclass);


--
-- Name: chore_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_preferences ALTER COLUMN id SET DEFAULT nextval('public.chore_preferences_id_seq'::regclass);


--
-- Name: chores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chores ALTER COLUMN id SET DEFAULT nextval('public.chores_id_seq'::regclass);


--
-- Name: engine_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.engine_events ALTER COLUMN id SET DEFAULT nextval('public.engine_events_id_seq'::regclass);


--
-- Name: household_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_members ALTER COLUMN id SET DEFAULT nextval('public.household_members_id_seq'::regclass);


--
-- Name: household_weeks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_weeks ALTER COLUMN id SET DEFAULT nextval('public.household_weeks_id_seq'::regclass);


--
-- Name: households id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.households ALTER COLUMN id SET DEFAULT nextval('public.households_id_seq'::regclass);


--
-- Name: invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations ALTER COLUMN id SET DEFAULT nextval('public.invitations_id_seq'::regclass);


--
-- Name: level_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_changes ALTER COLUMN id SET DEFAULT nextval('public.level_changes_id_seq'::regclass);


--
-- Name: member_pauses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_pauses ALTER COLUMN id SET DEFAULT nextval('public.member_pauses_id_seq'::regclass);


--
-- Name: notification_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences ALTER COLUMN id SET DEFAULT nextval('public.notification_preferences_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: split_gap_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_gap_entries ALTER COLUMN id SET DEFAULT nextval('public.split_gap_entries_id_seq'::regclass);


--
-- Name: split_setting_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_setting_changes ALTER COLUMN id SET DEFAULT nextval('public.split_setting_changes_id_seq'::regclass);


--
-- Name: task_handovers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_handovers ALTER COLUMN id SET DEFAULT nextval('public.task_handovers_id_seq'::regclass);


--
-- Name: tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks ALTER COLUMN id SET DEFAULT nextval('public.tasks_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: week_corrections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_corrections ALTER COLUMN id SET DEFAULT nextval('public.week_corrections_id_seq'::regclass);


--
-- Name: week_plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_plans ALTER COLUMN id SET DEFAULT nextval('public.week_plans_id_seq'::regclass);


--
-- Name: absence_answers absence_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_answers
    ADD CONSTRAINT absence_answers_pkey PRIMARY KEY (id);


--
-- Name: absence_inquiries absence_inquiries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_inquiries
    ADD CONSTRAINT absence_inquiries_pkey PRIMARY KEY (id);


--
-- Name: admin_actions admin_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_actions
    ADD CONSTRAINT admin_actions_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);


--
-- Name: approvals approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: chore_assignees chore_assignees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_assignees
    ADD CONSTRAINT chore_assignees_pkey PRIMARY KEY (id);


--
-- Name: chore_logs chore_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_logs
    ADD CONSTRAINT chore_logs_pkey PRIMARY KEY (id);


--
-- Name: chore_occurrences chore_occurrences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_occurrences
    ADD CONSTRAINT chore_occurrences_pkey PRIMARY KEY (id);


--
-- Name: chore_preferences chore_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_preferences
    ADD CONSTRAINT chore_preferences_pkey PRIMARY KEY (id);


--
-- Name: chores chores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chores
    ADD CONSTRAINT chores_pkey PRIMARY KEY (id);


--
-- Name: engine_events engine_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.engine_events
    ADD CONSTRAINT engine_events_pkey PRIMARY KEY (id);


--
-- Name: household_members household_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_members
    ADD CONSTRAINT household_members_pkey PRIMARY KEY (id);


--
-- Name: household_weeks household_weeks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_weeks
    ADD CONSTRAINT household_weeks_pkey PRIMARY KEY (id);


--
-- Name: households households_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.households
    ADD CONSTRAINT households_pkey PRIMARY KEY (id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: level_changes level_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_changes
    ADD CONSTRAINT level_changes_pkey PRIMARY KEY (id);


--
-- Name: member_pauses member_pauses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_pauses
    ADD CONSTRAINT member_pauses_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: split_gap_entries split_gap_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_gap_entries
    ADD CONSTRAINT split_gap_entries_pkey PRIMARY KEY (id);


--
-- Name: split_setting_changes split_setting_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_setting_changes
    ADD CONSTRAINT split_setting_changes_pkey PRIMARY KEY (id);


--
-- Name: task_handovers task_handovers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_handovers
    ADD CONSTRAINT task_handovers_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: week_corrections week_corrections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_corrections
    ADD CONSTRAINT week_corrections_pkey PRIMARY KEY (id);


--
-- Name: week_plans week_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_plans
    ADD CONSTRAINT week_plans_pkey PRIMARY KEY (id);


--
-- Name: idx_on_absence_inquiry_id_household_member_id_d7a225158d; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_absence_inquiry_id_household_member_id_d7a225158d ON public.absence_answers USING btree (absence_inquiry_id, household_member_id);


--
-- Name: idx_on_household_id_status_week_start_25d1d7005e; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_household_id_status_week_start_25d1d7005e ON public.household_weeks USING btree (household_id, status, week_start);


--
-- Name: idx_on_household_member_id_last_week_start_004aa25e77; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_household_member_id_last_week_start_004aa25e77 ON public.absence_inquiries USING btree (household_member_id, last_week_start);


--
-- Name: index_absence_answers_on_absence_inquiry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_absence_answers_on_absence_inquiry_id ON public.absence_answers USING btree (absence_inquiry_id);


--
-- Name: index_absence_answers_on_household_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_absence_answers_on_household_member_id ON public.absence_answers USING btree (household_member_id);


--
-- Name: index_absence_answers_on_member_pause_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_absence_answers_on_member_pause_id ON public.absence_answers USING btree (member_pause_id);


--
-- Name: index_absence_inquiries_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_absence_inquiries_on_household_id ON public.absence_inquiries USING btree (household_id);


--
-- Name: index_absence_inquiries_on_household_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_absence_inquiries_on_household_member_id ON public.absence_inquiries USING btree (household_member_id);


--
-- Name: index_absence_inquiries_on_status_and_deadline_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_absence_inquiries_on_status_and_deadline_at ON public.absence_inquiries USING btree (status, deadline_at);


--
-- Name: index_admin_actions_on_admin_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_actions_on_admin_user_id ON public.admin_actions USING btree (admin_user_id);


--
-- Name: index_admin_actions_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_actions_on_created_at ON public.admin_actions USING btree (created_at);


--
-- Name: index_admin_actions_on_record_type_and_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_actions_on_record_type_and_record_id ON public.admin_actions USING btree (record_type, record_id);


--
-- Name: index_admin_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admin_users_on_email ON public.admin_users USING btree (email);


--
-- Name: index_approvals_on_approvable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_approvals_on_approvable ON public.approvals USING btree (approvable_type, approvable_id);


--
-- Name: index_approvals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_approvals_on_user_id ON public.approvals USING btree (user_id);


--
-- Name: index_approvals_unique_per_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_approvals_unique_per_user ON public.approvals USING btree (approvable_type, approvable_id, user_id);


--
-- Name: index_chore_assignees_on_chore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_assignees_on_chore_id ON public.chore_assignees USING btree (chore_id);


--
-- Name: index_chore_assignees_on_invitation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_assignees_on_invitation_id ON public.chore_assignees USING btree (invitation_id);


--
-- Name: index_chore_assignees_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_assignees_on_user_id ON public.chore_assignees USING btree (user_id);


--
-- Name: index_chore_assignees_unique_invitation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chore_assignees_unique_invitation ON public.chore_assignees USING btree (chore_id, invitation_id) WHERE (invitation_id IS NOT NULL);


--
-- Name: index_chore_assignees_unique_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chore_assignees_unique_user ON public.chore_assignees USING btree (chore_id, user_id) WHERE (user_id IS NOT NULL);


--
-- Name: index_chore_logs_on_chore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_logs_on_chore_id ON public.chore_logs USING btree (chore_id);


--
-- Name: index_chore_logs_on_household_id_and_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_logs_on_household_id_and_completed_at ON public.chore_logs USING btree (household_id, completed_at);


--
-- Name: index_chore_logs_on_occurrence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_logs_on_occurrence_id ON public.chore_logs USING btree (occurrence_id);


--
-- Name: index_chore_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_logs_on_user_id ON public.chore_logs USING btree (user_id);


--
-- Name: index_chore_logs_on_user_id_and_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_logs_on_user_id_and_completed_at ON public.chore_logs USING btree (user_id, completed_at);


--
-- Name: index_chore_logs_unique_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chore_logs_unique_idempotency_key ON public.chore_logs USING btree (user_id, idempotency_key) WHERE (idempotency_key IS NOT NULL);


--
-- Name: index_chore_occurrences_on_chore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_occurrences_on_chore_id ON public.chore_occurrences USING btree (chore_id);


--
-- Name: index_chore_occurrences_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_occurrences_on_household_id ON public.chore_occurrences USING btree (household_id);


--
-- Name: index_chore_occurrences_on_household_id_and_due_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_occurrences_on_household_id_and_due_on ON public.chore_occurrences USING btree (household_id, due_on);


--
-- Name: index_chore_occurrences_unique_slot; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chore_occurrences_unique_slot ON public.chore_occurrences USING btree (chore_id, week_start, slot);


--
-- Name: index_chore_preferences_on_chore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_preferences_on_chore_id ON public.chore_preferences USING btree (chore_id);


--
-- Name: index_chore_preferences_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chore_preferences_on_user_id ON public.chore_preferences USING btree (user_id);


--
-- Name: index_chore_preferences_on_user_id_and_chore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chore_preferences_on_user_id_and_chore_id ON public.chore_preferences USING btree (user_id, chore_id);


--
-- Name: index_chores_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chores_on_created_by_id ON public.chores USING btree (created_by_id);


--
-- Name: index_chores_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chores_on_household_id ON public.chores USING btree (household_id);


--
-- Name: index_chores_on_household_id_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chores_on_household_id_and_active ON public.chores USING btree (household_id, active);


--
-- Name: index_chores_on_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chores_on_task_id ON public.chores USING btree (task_id);


--
-- Name: index_engine_events_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_engine_events_on_household_id ON public.engine_events USING btree (household_id);


--
-- Name: index_engine_events_on_household_id_and_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_engine_events_on_household_id_and_occurred_at ON public.engine_events USING btree (household_id, occurred_at);


--
-- Name: index_engine_events_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_engine_events_on_subject ON public.engine_events USING btree (subject_type, subject_id);


--
-- Name: index_engine_events_undelivered; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_engine_events_undelivered ON public.engine_events USING btree (occurred_at) WHERE (delivered_at IS NULL);


--
-- Name: index_household_members_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_household_members_on_household_id ON public.household_members USING btree (household_id);


--
-- Name: index_household_members_on_household_id_and_color; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_household_members_on_household_id_and_color ON public.household_members USING btree (household_id, color);


--
-- Name: index_household_members_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_household_members_on_user_id ON public.household_members USING btree (user_id);


--
-- Name: index_household_weeks_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_household_weeks_on_household_id ON public.household_weeks USING btree (household_id);


--
-- Name: index_household_weeks_on_household_id_and_week_start; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_household_weeks_on_household_id_and_week_start ON public.household_weeks USING btree (household_id, week_start);


--
-- Name: index_invitations_on_household_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_household_id_and_email ON public.invitations USING btree (household_id, email);


--
-- Name: index_invitations_on_invitee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_invitee_id ON public.invitations USING btree (invitee_id);


--
-- Name: index_invitations_on_inviter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_inviter_id ON public.invitations USING btree (inviter_id);


--
-- Name: index_invitations_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_on_token ON public.invitations USING btree (token);


--
-- Name: index_invitations_pending_on_email_and_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_pending_on_email_and_household_id ON public.invitations USING btree (email, household_id) WHERE ((state)::text = 'pending'::text);


--
-- Name: index_level_changes_on_absence_inquiry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_level_changes_on_absence_inquiry_id ON public.level_changes USING btree (absence_inquiry_id);


--
-- Name: index_level_changes_on_cancelled_level_change_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_level_changes_on_cancelled_level_change_id ON public.level_changes USING btree (cancelled_level_change_id);


--
-- Name: index_level_changes_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_level_changes_on_household_id ON public.level_changes USING btree (household_id);


--
-- Name: index_level_changes_on_household_week_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_level_changes_on_household_week_id ON public.level_changes USING btree (household_week_id);


--
-- Name: index_member_pauses_on_declared_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_pauses_on_declared_by_id ON public.member_pauses USING btree (declared_by_id);


--
-- Name: index_member_pauses_on_household_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_pauses_on_household_member_id ON public.member_pauses USING btree (household_member_id);


--
-- Name: index_member_pauses_on_household_member_id_and_starts_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_member_pauses_on_household_member_id_and_starts_on ON public.member_pauses USING btree (household_member_id, starts_on);


--
-- Name: index_notification_preferences_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_preferences_on_user_id ON public.notification_preferences USING btree (user_id);


--
-- Name: index_notification_preferences_on_user_id_and_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notification_preferences_on_user_id_and_event_type ON public.notification_preferences USING btree (user_id, event_type);


--
-- Name: index_notifications_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_household_id ON public.notifications USING btree (household_id);


--
-- Name: index_notifications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id ON public.notifications USING btree (user_id);


--
-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id_and_created_at ON public.notifications USING btree (user_id, created_at);


--
-- Name: index_notifications_on_user_id_and_dedup_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notifications_on_user_id_and_dedup_key ON public.notifications USING btree (user_id, dedup_key);


--
-- Name: index_notifications_weekly_cap; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notifications_weekly_cap ON public.notifications USING btree (user_id, cap_class, cap_week_start) WHERE ((channel IS NOT NULL) AND (cap_class IS NOT NULL));


--
-- Name: index_split_gap_entries_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_split_gap_entries_on_household_id ON public.split_gap_entries USING btree (household_id);


--
-- Name: index_split_gap_entries_on_household_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_split_gap_entries_on_household_id_and_user_id ON public.split_gap_entries USING btree (household_id, user_id);


--
-- Name: index_split_gap_entries_on_reset_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_split_gap_entries_on_reset_by_id ON public.split_gap_entries USING btree (reset_by_id);


--
-- Name: index_split_gap_entries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_split_gap_entries_on_user_id ON public.split_gap_entries USING btree (user_id);


--
-- Name: index_split_setting_changes_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_split_setting_changes_on_household_id ON public.split_setting_changes USING btree (household_id);


--
-- Name: index_split_setting_changes_on_proposed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_split_setting_changes_on_proposed_by_id ON public.split_setting_changes USING btree (proposed_by_id);


--
-- Name: index_split_setting_changes_one_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_split_setting_changes_one_pending ON public.split_setting_changes USING btree (household_id) WHERE ((status)::text = 'pending'::text);


--
-- Name: index_task_handovers_live; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_task_handovers_live ON public.task_handovers USING btree (chore_id, week_start, from_user_id) WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying])::text[]));


--
-- Name: index_task_handovers_on_chore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_handovers_on_chore_id ON public.task_handovers USING btree (chore_id);


--
-- Name: index_task_handovers_on_from_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_handovers_on_from_user_id ON public.task_handovers USING btree (from_user_id);


--
-- Name: index_task_handovers_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_handovers_on_household_id ON public.task_handovers USING btree (household_id);


--
-- Name: index_task_handovers_on_to_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_task_handovers_on_to_user_id ON public.task_handovers USING btree (to_user_id);


--
-- Name: index_tasks_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tasks_on_key ON public.tasks USING btree (key);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_week_corrections_on_declared_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_week_corrections_on_declared_by_id ON public.week_corrections USING btree (declared_by_id);


--
-- Name: index_week_corrections_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_week_corrections_on_household_id ON public.week_corrections USING btree (household_id);


--
-- Name: index_week_corrections_on_household_week_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_week_corrections_on_household_week_id ON public.week_corrections USING btree (household_week_id);


--
-- Name: index_week_corrections_on_household_week_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_week_corrections_on_household_week_id_and_user_id ON public.week_corrections USING btree (household_week_id, user_id);


--
-- Name: index_week_corrections_on_member_pause_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_week_corrections_on_member_pause_id ON public.week_corrections USING btree (member_pause_id);


--
-- Name: index_week_corrections_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_week_corrections_on_user_id ON public.week_corrections USING btree (user_id);


--
-- Name: index_week_plans_on_gap_waived_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_week_plans_on_gap_waived_by_id ON public.week_plans USING btree (gap_waived_by_id);


--
-- Name: index_week_plans_on_household_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_week_plans_on_household_id ON public.week_plans USING btree (household_id);


--
-- Name: index_week_plans_on_household_id_and_week_start; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_week_plans_on_household_id_and_week_start ON public.week_plans USING btree (household_id, week_start);


--
-- Name: index_week_plans_on_proposed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_week_plans_on_proposed_by_id ON public.week_plans USING btree (proposed_by_id);


--
-- Name: admin_actions admin_actions_no_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_actions_no_truncate BEFORE TRUNCATE ON public.admin_actions FOR EACH STATEMENT EXECUTE FUNCTION public.admin_actions_append_only();


--
-- Name: admin_actions admin_actions_no_update_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_actions_no_update_delete BEFORE DELETE OR UPDATE ON public.admin_actions FOR EACH ROW EXECUTE FUNCTION public.admin_actions_append_only();


--
-- Name: invitations fk_rails_00204dc74b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_00204dc74b FOREIGN KEY (invitee_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: split_gap_entries fk_rails_0c8014e10a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_gap_entries
    ADD CONSTRAINT fk_rails_0c8014e10a FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: task_handovers fk_rails_1438199f82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_handovers
    ADD CONSTRAINT fk_rails_1438199f82 FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: week_corrections fk_rails_158c09d187; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_corrections
    ADD CONSTRAINT fk_rails_158c09d187 FOREIGN KEY (member_pause_id) REFERENCES public.member_pauses(id) ON DELETE SET NULL;


--
-- Name: week_corrections fk_rails_1d26999572; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_corrections
    ADD CONSTRAINT fk_rails_1d26999572 FOREIGN KEY (declared_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: chores fk_rails_268bbde71b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chores
    ADD CONSTRAINT fk_rails_268bbde71b FOREIGN KEY (household_id) REFERENCES public.households(id);


--
-- Name: chore_assignees fk_rails_2ceedbbb66; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_assignees
    ADD CONSTRAINT fk_rails_2ceedbbb66 FOREIGN KEY (chore_id) REFERENCES public.chores(id) ON DELETE CASCADE;


--
-- Name: member_pauses fk_rails_2e46601976; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_pauses
    ADD CONSTRAINT fk_rails_2e46601976 FOREIGN KEY (household_member_id) REFERENCES public.household_members(id) ON DELETE CASCADE;


--
-- Name: split_setting_changes fk_rails_3396f0ab65; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_setting_changes
    ADD CONSTRAINT fk_rails_3396f0ab65 FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: household_members fk_rails_342c771846; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_members
    ADD CONSTRAINT fk_rails_342c771846 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: week_corrections fk_rails_3660fbbefe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_corrections
    ADD CONSTRAINT fk_rails_3660fbbefe FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: absence_answers fk_rails_380710c75b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_answers
    ADD CONSTRAINT fk_rails_380710c75b FOREIGN KEY (member_pause_id) REFERENCES public.member_pauses(id) ON DELETE SET NULL;


--
-- Name: household_weeks fk_rails_40a330c958; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_weeks
    ADD CONSTRAINT fk_rails_40a330c958 FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: member_pauses fk_rails_40b10a08c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_pauses
    ADD CONSTRAINT fk_rails_40b10a08c8 FOREIGN KEY (declared_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: chore_assignees fk_rails_426b5dabef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_assignees
    ADD CONSTRAINT fk_rails_426b5dabef FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chore_assignees fk_rails_4324111b7e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_assignees
    ADD CONSTRAINT fk_rails_4324111b7e FOREIGN KEY (invitation_id) REFERENCES public.invitations(id) ON DELETE CASCADE;


--
-- Name: chore_preferences fk_rails_46cccc49f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_preferences
    ADD CONSTRAINT fk_rails_46cccc49f4 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chore_logs fk_rails_49dbe008e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_logs
    ADD CONSTRAINT fk_rails_49dbe008e1 FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE SET NULL;


--
-- Name: week_plans fk_rails_4a3de6372a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_plans
    ADD CONSTRAINT fk_rails_4a3de6372a FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: level_changes fk_rails_4a75be932f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_changes
    ADD CONSTRAINT fk_rails_4a75be932f FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: split_gap_entries fk_rails_5a4a0a8fe3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_gap_entries
    ADD CONSTRAINT fk_rails_5a4a0a8fe3 FOREIGN KEY (reset_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: notifications fk_rails_5c22549406; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_5c22549406 FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE SET NULL;


--
-- Name: chore_logs fk_rails_61500d5c17; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_logs
    ADD CONSTRAINT fk_rails_61500d5c17 FOREIGN KEY (chore_id) REFERENCES public.chores(id) ON DELETE SET NULL;


--
-- Name: chore_logs fk_rails_7000e176e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_logs
    ADD CONSTRAINT fk_rails_7000e176e9 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: level_changes fk_rails_72b66bee3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_changes
    ADD CONSTRAINT fk_rails_72b66bee3f FOREIGN KEY (cancelled_level_change_id) REFERENCES public.level_changes(id) ON DELETE SET NULL;


--
-- Name: invitations fk_rails_7480156672; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_7480156672 FOREIGN KEY (inviter_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: household_members fk_rails_79aa12c2b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.household_members
    ADD CONSTRAINT fk_rails_79aa12c2b5 FOREIGN KEY (household_id) REFERENCES public.households(id);


--
-- Name: chore_occurrences fk_rails_7b5cf983da; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_occurrences
    ADD CONSTRAINT fk_rails_7b5cf983da FOREIGN KEY (chore_id) REFERENCES public.chores(id) ON DELETE CASCADE;


--
-- Name: invitations fk_rails_7c90338b97; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_7c90338b97 FOREIGN KEY (household_id) REFERENCES public.households(id);


--
-- Name: split_gap_entries fk_rails_804010a815; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_gap_entries
    ADD CONSTRAINT fk_rails_804010a815 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: week_corrections fk_rails_80c672f849; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_corrections
    ADD CONSTRAINT fk_rails_80c672f849 FOREIGN KEY (household_week_id) REFERENCES public.household_weeks(id) ON DELETE CASCADE;


--
-- Name: chore_logs fk_rails_8476d492d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_logs
    ADD CONSTRAINT fk_rails_8476d492d6 FOREIGN KEY (occurrence_id) REFERENCES public.chore_occurrences(id) ON DELETE SET NULL;


--
-- Name: absence_answers fk_rails_84e15905e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_answers
    ADD CONSTRAINT fk_rails_84e15905e0 FOREIGN KEY (household_member_id) REFERENCES public.household_members(id) ON DELETE CASCADE;


--
-- Name: absence_inquiries fk_rails_89209086ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_inquiries
    ADD CONSTRAINT fk_rails_89209086ad FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: admin_actions fk_rails_91394943a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_actions
    ADD CONSTRAINT fk_rails_91394943a2 FOREIGN KEY (admin_user_id) REFERENCES public.admin_users(id) ON DELETE RESTRICT;


--
-- Name: task_handovers fk_rails_91f9b126d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_handovers
    ADD CONSTRAINT fk_rails_91f9b126d0 FOREIGN KEY (chore_id) REFERENCES public.chores(id) ON DELETE CASCADE;


--
-- Name: level_changes fk_rails_93da7572ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_changes
    ADD CONSTRAINT fk_rails_93da7572ce FOREIGN KEY (household_week_id) REFERENCES public.household_weeks(id) ON DELETE SET NULL;


--
-- Name: notification_preferences fk_rails_9503aade25; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT fk_rails_9503aade25 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: level_changes fk_rails_9e6b8ae760; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_changes
    ADD CONSTRAINT fk_rails_9e6b8ae760 FOREIGN KEY (absence_inquiry_id) REFERENCES public.absence_inquiries(id) ON DELETE SET NULL;


--
-- Name: notifications fk_rails_b080fb4855; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_b080fb4855 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: chore_occurrences fk_rails_b3fcc3388d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_occurrences
    ADD CONSTRAINT fk_rails_b3fcc3388d FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: absence_inquiries fk_rails_bca7caf3dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_inquiries
    ADD CONSTRAINT fk_rails_bca7caf3dd FOREIGN KEY (household_member_id) REFERENCES public.household_members(id) ON DELETE CASCADE;


--
-- Name: week_plans fk_rails_c5d1ab873c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_plans
    ADD CONSTRAINT fk_rails_c5d1ab873c FOREIGN KEY (proposed_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: engine_events fk_rails_c5dc4d0202; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.engine_events
    ADD CONSTRAINT fk_rails_c5dc4d0202 FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE CASCADE;


--
-- Name: approvals fk_rails_cffbad0d08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT fk_rails_cffbad0d08 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: task_handovers fk_rails_dabd653a85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_handovers
    ADD CONSTRAINT fk_rails_dabd653a85 FOREIGN KEY (to_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: week_corrections fk_rails_dec9c4b832; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_corrections
    ADD CONSTRAINT fk_rails_dec9c4b832 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: task_handovers fk_rails_df64c48187; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_handovers
    ADD CONSTRAINT fk_rails_df64c48187 FOREIGN KEY (from_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: split_setting_changes fk_rails_df9a53e32a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.split_setting_changes
    ADD CONSTRAINT fk_rails_df9a53e32a FOREIGN KEY (proposed_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: chores fk_rails_e36dfa813c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chores
    ADD CONSTRAINT fk_rails_e36dfa813c FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE RESTRICT NOT VALID;


--
-- Name: absence_answers fk_rails_e3eb8ec063; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.absence_answers
    ADD CONSTRAINT fk_rails_e3eb8ec063 FOREIGN KEY (absence_inquiry_id) REFERENCES public.absence_inquiries(id) ON DELETE CASCADE;


--
-- Name: chore_preferences fk_rails_f8a28d0faf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chore_preferences
    ADD CONSTRAINT fk_rails_f8a28d0faf FOREIGN KEY (chore_id) REFERENCES public.chores(id) ON DELETE CASCADE;


--
-- Name: chores fk_rails_fd4ebb1698; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chores
    ADD CONSTRAINT fk_rails_fd4ebb1698 FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: week_plans fk_rails_fecb7aa8ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.week_plans
    ADD CONSTRAINT fk_rails_fecb7aa8ca FOREIGN KEY (gap_waived_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict Ql9pAnvL60hORjPoFeqKdF29BRgMQrGaIXYPrHY2PaVliad2opolt8tLRai3h58

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261113092400'),
('20261113092300'),
('20261113092200'),
('20261113092100'),
('20261113092000'),
('20261113091400'),
('20261113091300'),
('20261113091200'),
('20261113091100'),
('20261113090900'),
('20261113090800'),
('20261113090700'),
('20261113090600'),
('20261113090500'),
('20261113090400'),
('20261113090300'),
('20261113090200'),
('20261113090100'),
('20261113090000'),
('20261112130000'),
('20261112120000'),
('20261112110000'),
('20261112100000'),
('20261110100400'),
('20261110100300'),
('20261110100200'),
('20261110100100'),
('20261110100000'),
('20261108100500'),
('20261108100400'),
('20261108100300'),
('20261108100200'),
('20261108100100'),
('20261108100000'),
('20260926173338'),
('20260609210809'),
('20260609210807'),
('20260609172035'),
('20260609172033'),
('20260609172031'),
('20260609150834'),
('20260609150832'),
('20260609120455'),
('20260609120453'),
('20250116122559'),
('20250116122510'),
('20250115150052'),
('20250114150327'),
('20250114150034'),
('20250114145752');

