function [t_all, t_by_method, t_pair] = eeg_collect_prep05_summary(cfg_or_qc_root)
% EEG_COLLECT_PREP05_SUMMARY Public entry point for Step-05 QC collection.
%
% All implementation functions are centralized in eeg_pipeline_helpers.m.

if nargin < 1
    cfg_or_qc_root = [];
end

bootstrap_log = fullfile(tempdir, 'eeg_collect_prep05_summary_bootstrap.log');
helpers = eeg_pipeline_helpers(bootstrap_log);
[t_all, t_by_method, t_pair] = ...
    helpers.collect_prep05_summary(cfg_or_qc_root);
end
