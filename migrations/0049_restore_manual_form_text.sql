UPDATE order_items
SET manual_form_submission_json = REPLACE(
  REPLACE(
    REPLACE(
      REPLACE(
        REPLACE(manual_form_submission_json, '&quot;', '\"'),
        '&#39;', ''''
      ),
      '&lt;', '<'
    ),
    '&gt;', '>'
  ),
  '&amp;', '&'
)
WHERE manual_form_submission_json LIKE '%&quot;%'
   OR manual_form_submission_json LIKE '%&#39;%'
   OR manual_form_submission_json LIKE '%&lt;%'
   OR manual_form_submission_json LIKE '%&gt;%'
   OR manual_form_submission_json LIKE '%&amp;%';
