function [t_all, output_paths] = eeg_collect_prep03_summary(cfg_or_qc_root)
% Collect ICA training summaries into one table.
%
% Example:
%   cfg = eeg_pipeline_config();
%   [T, files] = eeg_collect_prep03_summary(cfg);
%
% Run this after Step 03 has finished.
% Existing datasets without summary CSVs are not added automatically.

if nargin < 1
    cfg_or_qc_root = [];
end

helpers = eeg_pipeline_helpers( ...
    fullfile(tempdir, 'eeg_collect_prep03_summary.log'));

[t_all, output_paths] = helpers.collect_prep03_summary(cfg_or_qc_root);
end