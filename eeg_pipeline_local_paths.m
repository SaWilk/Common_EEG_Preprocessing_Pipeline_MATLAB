function local = eeg_pipeline_local_paths()
% eeg_pipeline_local_paths
% adjust this file locally on your PC with the local paths.
% Replace "CHANGE_ME_*" with your real paths.

local = struct();

local.pc = struct();
local.pc.source_eeg_root  =  "CHANGE_ME_PATH-EEG-ROOT";   % insert local paths, e.g. fullfile('C:/.../.../data")
local.pc.source_beh_root  = "";                               % leave empty if unused
local.pc.bids_root        = "CHANGE_ME_PATH-BIDS-ROOT";        %insert local paths, e.g. fullfile('C:/.../.../bids_root")
local.pc.derivatives_root = "CHANGE_ME_PATH-DERIVATIVES-ROOT";  % insert loca paths, e.g. fullfile('C:/.../.../derivatives")

local.server_windows = struct();
local.server_windows.source_eeg_root  = local.pc.source_eeg_root;
local.server_windows.source_beh_root  = "";
local.server_windows.bids_root        = local.pc.bids_root;
local.server_windows.derivatives_root = local.pc.derivatives_root;

local.hpc_hummel = struct();
local.hpc_hummel.source_eeg_root  = ""; % empty on HPC
local.hpc_hummel.source_beh_root  = "";
local.hpc_hummel.bids_root        = "CHANGE_ME_HPC_PATH_BIDS-ROOT";         % insert path on HPC. e.g. fullfile('/.../u/.../sourcedata/bids_root')
local.hpc_hummel.derivatives_root = "CHANGE_ME_HPC_PATH_DERIVATIVES-ROOT";  % insert path on HPC, e.g. "/.../u/.../derivatives/..."

% Toolboxes
local.toolboxes = struct(); %insert paths to toolboxes for EEGLab, FASTER, and ERPLab

local.toolboxes.eeglab_pc  = "CHANGE_ME_PATH_EEGLAB"; % insert local path, e.g."C:\...\...\toolboxes\eeglab2026.0.0"
local.toolboxes.eeglab_server = "CHANGE_ME_PATH_EEGLAB"; % insert local path, e.g."C:\...\...\toolboxes\eeglab2026.0.0"
local.toolboxes.eeglab_hpc = "CHANGE_ME_HPC_PATH_EEGLAB"; % insert HPC path, e.g."...\u\...\toolboxes\eeglab2026.0.0"

local.toolboxes.faster_pc  = "CHANGE_ME_PATH_FASTER"; % insert local path, e.g."C:\...\...\toolboxes\FASTER"
local.toolboxes.faster_server = "CHANGE_ME_PATH_FASTER"; % insert local path, e.g."C:\...\...\toolboxes\FASTER"
local.toolboxes.faster_hpc = "CHANGE_ME_HPC_PATH_FASTER"; % insert HPC path, e.g."...\u\...\toolboxes\FASTER"

local.toolboxes.erplab_pc  = "CHANGE_ME_PATH_EEGLAB-ERPLAB"; % insert local path, e.g."C:\...\...\toolboxes\eeglab2026.0.0\plugins\ERPLAB12.20"
local.toolboxes.erplab_server = "CHANGE_ME_PATH_EEGLAB-ERPLAB"; % insert local path, e.g."C:\...\...\toolboxes\eeglab2026.0.0\plugins\ERPLAB12.20"
local.toolboxes.erplab_hpc = "CHANGE_ME_HPC_PATH_EEGLAB-ERPLAB"; % insert HPC path, e.g."...\u\...\toolboxes\eeglab2026.0.0\plugins\ERPLAB12.20"

end