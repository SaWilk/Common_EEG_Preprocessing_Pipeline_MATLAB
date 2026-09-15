function [t_all, t_by_method, t_pair, t_reasons, output_paths] = eeg_collect_prep06_summary(cfg_or_qc_root)
% EEG_COLLECT_PREP06_SUMMARY Compatibility entry point for manual use.
%
% Step 06 now calls the same collector automatically. All implementation
% lives in eeg_pipeline_helpers.m so step files contain calls only.

if nargin < 1
    cfg_or_qc_root = [];
end

helpers = eeg_pipeline_helpers(fullfile(tempdir, 'eeg_collect_prep06_summary.log'));
[t_all, t_by_method, t_pair, t_reasons, output_paths] = ...
    helpers.collect_prep06_summary(cfg_or_qc_root);
end
