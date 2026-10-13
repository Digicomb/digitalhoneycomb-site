-- Contact requests from the digitalhoneycomb.com "Start a conversation" form.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Security model: the website uses the public (publishable/anon) key. Visitors can
-- INSERT a request, but cannot read, update or delete any rows. View requests in the
-- dashboard (Table Editor) or with the service_role key, which never goes in the site.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------

create table if not exists public.contact_requests (
	id uuid primary key default gen_random_uuid(),
	name text not null,
	email text not null,
	company text,
	interest text,
	message text not null,
	source text,
	created_at timestamptz not null default now(),

	constraint contact_name_length check (char_length(name) between 1 and 120),
	constraint contact_email_format check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
	constraint contact_email_length check (char_length(email) <= 254),
	constraint contact_company_length check (char_length(company) <= 160),
	constraint contact_interest_length check (char_length(interest) <= 80),
	constraint contact_message_length check (char_length(message) between 1 and 4000),
	constraint contact_source_length check (char_length(source) <= 60)
);

alter table public.contact_requests enable row level security;

-- Only allow inserts from the website; no select/update/delete policies exist,
-- so the public key cannot read requests back.
revoke all on public.contact_requests from anon, authenticated;
grant insert (name, email, company, interest, message, source) on public.contact_requests to anon, authenticated;

drop policy if exists "Website visitors can send a contact request" on public.contact_requests;
create policy "Website visitors can send a contact request"
	on public.contact_requests
	for insert
	to anon, authenticated
	with check (true);

-- ---------------------------------------------------------------------------
-- 2. Email notification via Resend
-- ---------------------------------------------------------------------------

create extension if not exists pg_net with schema extensions;

-- Settings are stored in Supabase Vault (encrypted). Set them ONCE by running the
-- block below with your real values filled in (replace the <...> placeholders).
-- To change a value later: Project Settings -> Vault, or
--   select vault.update_secret((select id from vault.secrets where name = 'resend_api_key'), 're_new_key');
--
-- select vault.create_secret('<your Resend API key, starts with re_>', 'resend_api_key');
-- select vault.create_secret('<inbox that should receive requests>', 'contact_notify_to');
-- select vault.create_secret('Digital Honeycomb <notifications@digitalhoneycomb.com>', 'contact_notify_from');

create or replace function public.notify_contact_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
	api_key text;
	notify_to text;
	notify_from text;
	body_text text;
begin
	select decrypted_secret into api_key from vault.decrypted_secrets where name = 'resend_api_key';
	select decrypted_secret into notify_to from vault.decrypted_secrets where name = 'contact_notify_to';
	select decrypted_secret into notify_from from vault.decrypted_secrets where name = 'contact_notify_from';

	-- Not configured yet: keep the request, skip the email.
	if api_key is null or notify_to is null or notify_from is null then
		return new;
	end if;

	-- Plain text only, so nothing a visitor types can inject HTML into the email.
	body_text := concat_ws(E'\n',
		'New conversation request from digitalhoneycomb.com',
		'',
		'Name:     ' || new.name,
		'Email:    ' || new.email,
		'Company:  ' || coalesce(new.company, '-'),
		'Interest: ' || coalesce(new.interest, '-'),
		'Sent:     ' || to_char(new.created_at at time zone 'America/New_York', 'YYYY-MM-DD HH24:MI TZ'),
		'',
		new.message,
		'',
		'-- Reply to this email to answer ' || new.name || ' directly.'
	);

	-- Asynchronous: the HTTP call runs after the insert commits and never blocks the visitor.
	perform net.http_post(
		url := 'https://api.resend.com/emails',
		headers := jsonb_build_object(
			'Authorization', 'Bearer ' || api_key,
			'Content-Type', 'application/json'
		),
		body := jsonb_build_object(
			'from', notify_from,
			'to', jsonb_build_array(notify_to),
			'reply_to', new.email,
			'subject', 'New conversation request: ' || left(new.name, 60),
			'text', body_text
		)
	);

	return new;
end;
$$;

revoke all on function public.notify_contact_request() from public, anon, authenticated;

drop trigger if exists contact_request_notify on public.contact_requests;
create trigger contact_request_notify
	after insert on public.contact_requests
	for each row
	execute function public.notify_contact_request();

-- ---------------------------------------------------------------------------
-- 3. Keep-alive
-- ---------------------------------------------------------------------------

-- Returns the database time. Exposes no data; callable with the public key at
-- POST /rest/v1/rpc/keep_alive. Called by .github/workflows/supabase-keepalive.yml.
create or replace function public.keep_alive()
returns timestamptz
language sql
stable
set search_path = ''
as $$
	select now();
$$;

revoke all on function public.keep_alive() from public;
grant execute on function public.keep_alive() to anon, authenticated;
