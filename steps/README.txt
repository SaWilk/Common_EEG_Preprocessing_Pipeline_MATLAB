This Folder contains 
- the steps that are called by the runner script "run_eeg_pipeline". Normally These do not Need editing but if you want to add funcitonality to the Pipeline, you must modify the step files
- the helpers file; this contains all the functions called by the step files and therefore contains most of the code. 
- summary files; These do not Need to be run normally as the summary functions are automatically called within the steps files. however if you want to Regenerate the tables without running the whole Pipeline again, this is the way to do it. 