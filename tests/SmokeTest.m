classdef SmokeTest < matlab.unittest.TestCase
    
    methods (TestClassSetup)
        % Shared setup for the entire test class

        % Set up paths in test folder

            % add teardown: delete folders again

        % move test_config and test_paths into parentfolder, then cd into parent folder
            % add teardown: move test_files back
    end

    methods (TestMethodSetup)
        % Setup for each test
    end

    methods (Test)
        % Test methods
        
        function helpersCodeAnalysis(testCase)
            % Test that the helper functions pass code analysis
            testFile = mfilename('fullpath');
            repoRoot = fileparts(fileparts(testFile));
            stepsDir = fullfile(repoRoot, 'steps');
            helpers_path = fullfile(stepsDir, 'eeg_pipeline_helpers.m');
            diagnostics = codeIssues(helpers_path);
            testCase.verifyFalse(any(diagnostics.Issues.('Severity')== 'error'), 'Code Errors in pipeline_helpers!');
        end

        function stepsCodeAnalysis(testCase)
            testFile = mfilename('fullpath');
            repoRoot = fileparts(fileparts(testFile));
            stepsDir = fullfile(repoRoot, 'steps');
            files = dir(fullfile(stepsDir, "eeg_prep*.m"));
            for f = 1:numel(files)
                filePath = fullfile(files(f).folder, files(f).name);
                diagnostics = codeIssues(filePath);
                testCase.verifyFalse(any(diagnostics.Issues.('Severity')== 'error'), ...
                    sprintf('Code Errors in %s!', files(f).name));
            end
        end

    end

end