-- encounter_claims feature flag at covered-entity level.
-- In this schema the covered entity IS the workspace (workspace.coveredEntityName,
-- coveredEntityType, id340B, ...), so the flag lives on feature_flag.workspace_id
-- with entity_type = 'WORKSPACE'. There is no covered_entity_id column.
--
-- Run order matters: seed the DISABLE default first (DO NOTHING so it never
-- clobbers an existing value), then apply the ENABLE queries.

-- 0) Preflight: confirm the unique index ON CONFLICT relies on exists in the live DB.
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'feature_flag'::regclass AND contype = 'u';
-- also OK if it is an index rather than a constraint:
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'feature_flag';


-- 1) Default DISABLE for every live workspace. DO NOTHING so re-running
--    (or running after the ENABLE queries) does not reset enabled workspaces.
INSERT INTO feature_flag (id, workspace_id, feature_name, value, entity_type, created_at, updated_at)
SELECT gen_random_uuid()::text, w.id, 'encounter_claims', 'DISABLE', 'WORKSPACE', now(), now()
FROM workspace w
WHERE COALESCE(w."isDeleted", false) = false
ON CONFLICT (workspace_id, feature_name) DO NOTHING;

