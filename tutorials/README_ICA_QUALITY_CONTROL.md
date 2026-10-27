# ICA quality control

RUNICA and single-model AMICA receive the same rank, matrix, ICLabel, and before/after signal checks. AMICA additionally 
reports its
available convergence information.
As a rule of thumb, AMICA should produce higher-quality outputs but takes around three to four times longer to run. 
The purpose of this quality control tutorial is to help you establish which method to use via giving feedback on how well 
the ICA worked on your datasets. In general, use the same type of ICA for all participants in one dataset.

## What to inspect after a run

Start with these two files:

```text
<derivatives_root>/logs/<timestamp>_pipeline_subject_status.csv
<derivatives_root>/qc/<timestamp>_ica_qc_overview.csv
```

The first file lists every processed subject, the final pipeline status, the
failure reason, the recommended action, and the corresponding subject log. The
second file contains one row per ICA run with the overall ICA-QC status and a
decision-oriented recommendation. The master log also contains all failures and
all ICA warnings, but it is not necessary to reconstruct results from console
output.

Use `overall_status`, `decision`, `diagnosis`, and `recommended_action` in the
ICA overview as the primary review columns:

| Decision | What to do |
| --- | --- |
| `accept` | No ICA-QC action is required. |
| `accept_with_warning` | The cleaned dataset was saved. Review examples in the validation sample; do not inspect every subject by default. |
| `adjust_iclabel_or_try_other_ica` | If brain-like ICs were misclassified, raise the threshold for the dominant class or disable that class and rerun Step 05. If the decomposition itself looks implausible, rerun Step 04 with the other ICA method. |
| `try_other_ica_before_exclusion` | Rerun Step 04 with the other ICA method before excluding the dataset. Change ICLabel only when the rejected components were actually misclassified. |
| `repair_input_then_rerun_ica` | Check the Step-03 training data, bad/interpolated channels, sample count, and rank; then rerun ICA. If the input is valid and the problem recurs, try the other ICA method. |
| `try_runica_or_repair_step03` / `try_amica_or_repair_step03` | The selected ICA did not return usable output. Check Step 03 once and then try the alternative method. Exclude only if both decompositions remain invalid. |

## What causes a warning or failure?

Warnings are intended for aggregate QC and validation-sample review, not mandatory
subject-by-subject inspection. Routine processing can continue without action.

The supplied study configurations warn when median pre/post channel correlation
is below `0.80`, relative change RMS is above `0.85` (`0.75` in the generic
template), or the post/pre RMS ratio is outside `[0.50, 1.10]`. A pre-existing
flat channel also produces a warning. A large RMS reduction can be reasonable
when the original recording was dominated by ocular or other high-amplitude
noise. It is evidence of a large change, not evidence by itself that cleaning
was wrong.

Immediate hard failures are restricted to objectively unusable output, such as
changed data dimensions, non-finite values, or signal metrics that cannot be
computed. Other suspicious results use a combination rule. The supplied
configurations define the following *extreme indicators*:

- at least `95%` of ICs are removed;
- fewer than two ICs remain;
- IC removal creates additional flat channels;
- median pre/post channel correlation is at or below `0.10`;
- relative change RMS reaches at least `10.00`; or
- post/pre RMS ratio is at or below `0.10` or at least `10.00`.

The indicators are grouped into independent problem domains: extreme IC
rejection, newly created flat channels, extreme waveform-shape change, and
extreme signal-scale change. Related measurements within one domain count only
once. In particular, an extreme RMS ratio and an extreme relative RMS change
are both `EXTREME_SIGNAL_SCALE`; they cannot fail a subject merely by describing
the same scale change twice. One extreme domain still produces only a warning
and the cleaned dataset is saved. Step 05 fails only when at least two
independent extreme domains occur together.
The required count is configurable through
`signal_qc_min_extreme_metrics_to_fail`, but should normally remain at `2`.
The summary tables report the number and names of these independent domains in
`extreme_metric_count`, `extreme_metric_codes`, and
`extreme_metrics_required_to_fail` so the decision remains traceable without
checking the console or every participant manually.

## Interpreting the three routine signal metrics

| Metric | Practical meaning |
| --- | --- |
| `median_channel_correlation` | How similar the typical channel waveform remains after IC removal. Lower values mean stronger temporal alteration. |
| `relative_change_rms` | Size of the removed signal relative to the original signal. Higher values mean a larger intervention. |
| `rms_ratio` | Remaining RMS divided by original RMS. Values below one mean amplitude reduction; values above one mean amplification. |

No single finite metric fails a run. A low RMS ratio can be entirely reasonable
when a small number of convincing ocular components dominated the recording.
Only the combination rule or an objectively invalid output blocks the dataset.

## ICLabel actions

Artifact classes remain independently configurable for eye, muscle, heart, line
noise, channel noise, other, and low-brain components. Raising a class threshold
removes fewer components; lowering it removes more.

Only change an ICLabel threshold if the component table or a validation-sample
topography shows that the class was misidentified or too broadly rejected.
ICLabel settings cannot repair invalid ICA matrices, non-finite signals, rank
problems, or AMICA convergence problems. In those cases, repair the Step-03
input or try the other ICA method.

## AMICA convergence

AMICA is fixed to one model. Invalid matrices, an invalid model count, or
non-finite convergence output remain hard failures. Reaching `amica_max_iter`
with otherwise valid matrices is a warning: the Step-04 dataset is retained and
the final decision also considers Step-05 signal QC. When update-norm history is
disabled, the log reports `final_update_max=not_saved`; this is not a numerical
failure. If many subjects reach the cap, use RUNICA consistently for the cohort
or increase `amica_max_iter` once only when the extra runtime is acceptable.

RUNICA's `pop_runica` interface does not return an equivalent optimization
history. RUNICA still receives the same rank, matrix, ICLabel, and signal checks.
Its raw iteration messages do not have to be monitored during a cohort run;
matrix/runtime failures are caught and written to the status files.

## Lightweight defaults and optional diagnostics

Routine processing writes one Step-04 and one Step-05 subject summary plus the
per-component ICLabel table. Duplicate per-run summaries, near-threshold
edge-case flags, component-topography PNGs, and residual mutual-information
estimation are disabled by default. This avoids thousands of files and removes
metrics that do not provide a universal action threshold.

For a small validation sample, the optional diagnostics can be enabled with:

```matlab
cfg.prep_05.save_ic_topos_png = true;
cfg.prep_05.iclabel_edge_margin = 0.10;
cfg.prep_05.compute_decomposition_qc = true;
```

Residual pairwise mutual information is then reported descriptively; lower
values indicate more independent component activations. It should not be used
as a stand-alone pass/fail criterion.

## Detailed files

Detailed ICA QC remains below:

```text
<derivatives_root>/qc/<subject>/<ica_method>/
```

The default files are:

```text
*_prep04_ica_summary.csv    Step-04 integrity and AMICA status
*_iclabel_components.csv    ICLabel scores and keep/remove decision per IC
*_prep05_summary.csv        IC rejection and signal QC for all subject runs
```

Only open these detailed files for warnings or failures identified in the two
cohort-level overview files. Full exception reports are stored in subject logs;
failed subject logs end in `_ERR.log`.

## Further reading

- [EEGLAB ICA artifact-rejection tutorial](https://eeglab.org/tutorials/06_RejectArtifacts/RunICA.html)
- [EEGLAB `pop_runica` source and interface](https://github.com/sccn/eeglab/blob/develop/functions/popfunc/pop_runica.m)
