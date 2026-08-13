What this is: 
This EEG preprocessing Pipeline is intended to provide a Standard preprocessing procedure for the KPP, KPN (Uni Hamburg) and DFG-RU5389 as decided in a joint meeting in January 2026, in which common practises in preprocessing EEG data were agreed upon. It is set to these sensible defaults - plus some common practices - but fully configurable so you can adjust it to your specific setup. 

Before you start:
This pipeline requires EEGLab (https://eeglab.org/) with the ERPLAB Extension by default, which in turn depend on the following MATALB toolboxes: Signal processing toolbox and Statistics toolbox. 
Depending on the preprocessing options you choose, you may need to additionally install AMICA, cleanline or FASTER (as alternative to ERPLAB).

How to use: 
open eeg_pipeline_config. Take your time to adjust the paths and decide on the preprocessing settings that suit your analysis. Note: if you change the name of the file, you also need to change the name of the function at the top of the script.
once you are done, test the pipeline with one subject on your local machine: 
to that end, type "run_eeg_pipeline(<CONFIG_NAME>, <SUBJECT_ID>)", where <CONFIG_NAME> is the name of the file you just spent some time fitting to your needs, and <SUBJECT_ID> is the id of the test subject (e.g. "run_eeg_pipeline('eeg_pipeline_config','003')"). 
Fix any issues with paths, config options etc as they pop up. 
if you want to run the pipeline on the hummel cluster, note that you cannot use AMICA ICA (it will be automatically disabled). As a first step, follow the instructions in "how to run on hummel" and after you are done "Transfer files hummel-Z"

What the steps do: 
01 BIDS formatting: turns your raw brainvision eeg files folder into a BIDS-formatted file structure. You may expand this to also copy other data adjacent to yours into the same folder structure
02 triggerfix: renames triggers according to phases / different conditions. currently not yet generic but will be made generic in a very soon patch
03 until ica: main preprocessing step. all filtering, bad channel detection, channel naming, etc. is done. aditionally a copy of the dataset that is to be used for ica training is saved 
04 ica: runs the ica
05 after ica: automatically rejects components based on icweights and iclabel settings
06 epoching: cuts the data into epochs and applies epoch rejection on artifacts that survived all prior cleaning steps.

What if something doesn't work? 
If you are 80 % sure you found a bug in the script and didn't just set some config options improperly or if you are really annoyed with the way the config is shaped in an area that is important to your work, then contact the author Saskia Wilken (saskia.wilken@uni-hamburg.de) for support. 
In a bug report, please provide an explanation of what exactly one needs to do to recreate your issue and also provide the exact error message or a screenshot of it.


License

Copyright (C) 2025–2026 Saskia Wilken and contributors.

This project is licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later). See the LICENSE file for details.

Third-party software

The Common EEG Preprocessing Pipeline relies on EEGLAB and ERPLAB and, depending on the selected configuration, may use additional third-party software such as FASTER, AMICA, and CleanLine. These dependencies are not included in or distributed as part of this repository and must be installed separately.

All third-party packages remain subject to their respective licenses and terms of use. The license of this project applies only to the software contained in this repository, except where individual files explicitly state otherwise. MATLAB and any required MathWorks toolboxes are likewise not included and are subject to the applicable MathWorks license terms.