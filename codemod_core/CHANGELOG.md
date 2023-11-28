# 1.0.1
- Added additional expectations for the named generated test and removed the print statement.
- Modified change_set so that it always creates the output file even if no patches were included. This creates a more consistent expectation - I apply a changes set and an output file is created.
- updated the barrel file to reflect that file utils have been moved to core.
- moved file_query_util into core as we needed access for examples.
- applied lint_hard and cleaned up the resulting lints.
- Added a 'collision' list to the ChangeSet so you can get a list of overlapping patches that were skipped.
- Moved the applyPatches and applyPatchesAndSave to the ChangeSet class.
- Added option to ignore overlapping patches.
- modified run_interactive to use the new patch_generator
- split the project into two packages, codemon and codemon_core. The codemon package has exactly the same functionality as before except that the underlying ast traversal and creation of patches has been moved to codemon_core. The idea is that codemon_core can be used as an standalone API outside of the codemon CLI tooling.
- support destPaths

## 1.0.0

- Initial version.
