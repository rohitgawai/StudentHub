-- Removes temporary rows created during end-to-end verification of the
-- review-role-request flow. Safe to re-run.
delete from public.role_requests where id = 'req_test_01';
delete from public.profiles where user_id in ('usr_admin_test', 'usr_applicant_test');