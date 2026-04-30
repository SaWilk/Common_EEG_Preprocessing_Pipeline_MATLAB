What this is: 
This EEG preprocessing Pipeline is intended to provide a Standard preprocessing procedure for the KPP, KPN and RU5389 as decided in a joint meeting in January 2026, in which common practises in preprocessing EEG data were agreed upon. It is set to these sensible defaults - plus some common practices - but fully configurable so you can adjust it to your specific setup. 

Before you start:

This pipeline requires EEGLab (https://eeglab.org/) with the 'FASTER' Extension, which in turn depend on the following MATALB toolboxes: Signal processing toolbox and Statistics toolbox. 
Depending on the preprocessing options you choose, you may also need AMICA and cleanline.

How to use: 

open eeg_pipeline_config. Take your time to adjust the paths and decide on the preprocessing settings that suit your analysis. Note: if you change the name of the file, you also need to change the name of the function at the top of the script.
once you are done, test the pipeline with one subject on your local machine: 
to that end, type "run_eeg_pipeline(<CONFIG_NAME>, <SUBJECT_ID>)", where <CONFIG_NAME> is the name of the file you just spent some time fitting to your needs, and <SUBJECT_ID> is the id of the test subject (e.g. "run_eeg_pipeline('eeg_pipeline_config','003')"). 
Fix any issues with paths, config options etc as they Pop up. 

What if something doesn't work? 

If you are 80 % sure you found a bug in the script and didn't just set some config options improperly or if you are really annoyed with the way the config is shaped in an area that is important to your work, then contact the author Saskia Wilken (saskia.wilken@uni-hamburg.de) for support. 
In a bug report, please provide an explanation of what exactly one needs to do to recreate your issue and also provide the exact error message or a screenshot of it.

