```{=latex}
\begin{titlepage}
\centering
\vspace*{2cm}
```

::: {custom-style="Title Page"}
**A Smartphone-Based Prototype for Indoor Obstacle Awareness: Real-Time Object
Detection, Distance Estimation, and Audio-Haptic Feedback for Blind and
Visually Impaired Users**

Dissertation

By **Albin Shajan** (M01097740)

Supervisor: Dr. Ikram Ur Rehman\
Module CST4275 · MSc Data Science and Artificial Intelligence\
Middlesex University Dubai

1st October 2026

This thesis is submitted in part fulfilment of the requirements for MSc Data
Science and Artificial Intelligence at Middlesex University, 2026.
:::

```{=latex}
\end{titlepage}
\pagenumbering{roman}
\setcounter{page}{1}
```

# Abstract

Around 2.2 billion people live with some form of visual impairment (World
Health Organization, 2019). The long cane detects obstacles on the ground plane
reliably, but only on contact, and it says nothing about what an obstacle is or
about anything above sweep height. This project asks whether a consumer
smartphone can supply the missing information indoors: what is nearby, and how
close. The scope is **obstacle awareness**, not navigation, and the system is
positioned throughout as a supplement to the cane, never a replacement. The
research gap it addresses is that systems in this literature report detection
accuracy and inference speed separately from deployment cost, and rarely
validate their distance estimates against independently measured physical
ground truth.

Three detectors, YOLOv8n, YOLO11n and YOLO26n, were fine-tuned under identical
settings on an indoor corpus split by scene to prevent leakage, and were then
benchmarked on an iPhone 13 Pro Max for accuracy, end-to-end latency and
deployment cost. Distance estimation compared the phone's built-in LiDAR
against a monocular metric-depth network on 102 frames of obstacles placed at
tape-measured distances from 0.5 m to 4.5 m. A working prototype then combined
detection and depth with a derived-feature layer and graded audio and haptic
feedback.

YOLO26n was best on every axis measured: pooled mAP50-95 of 0.170 against about
0.125, the fewest parameters, the smallest package and sustained latency tied
for fastest. At the prototype's operating threshold its lead survives a
scene-level bootstrap, and its errors are misses rather than confusions: it
names 89 % of the objects it finds correctly but finds only 21 % of those
present. Buffer conversion and resizing took about 43 % of pipeline latency, so
inference timings understate real cost substantially. Retraining experiments
showed that data, not training time or model capacity, limits accuracy.
Completing annotations the corpus had omitted doubled recall on its two weakest
classes. Yet the model that won every photograph benchmark drew confident door
boxes over empty corridor floor in the setting the prototype was built for.

LiDAR estimated distance with a mean absolute error of 0.188 m (95 % interval
0.12–0.26 m; 16.1 % MAPE) against 1.221 m (69.7 %) for the monocular network,
and was closer to the tape measure in all 35 paired frames; for doors the error
was 0.077 m. The monocular error was almost entirely a systematic
over-estimate, which an exploratory recalibration reduced to 0.22 m. The
binding constraint was detection rather than depth: the detector returned a
box in 38 of the 102 frames, and a correctly named box on the photographed
object in only 11.

The prototype runs at 29.8 frames per second with 13.3 ms of processing per
frame, of which the decision layer takes 0.066 ms, and its geometry and scoring
pass 45 checks against planted values. With depth sensing and feedback active,
the phone reaches a `serious` thermal state within two to five minutes.

The planned evaluation with blindfolded sighted participants was not carried
out, so the contribution of the haptic channel is unmeasured and this thesis
contains no usability evidence. The prototype demonstrates technical
feasibility only and is not ready for use by blind or visually impaired people.
The contributions are a distance-accuracy measurement against physical ground
truth, a joint on-device benchmark, and evidence that benchmark rank and
behaviour in the deployment setting can point in opposite directions.

# Acknowledgements

I am grateful to my supervisor, Dr Ikram Ur Rehman, for his guidance throughout
this project.

His intervention on the choice of topic, early on, shaped the work decisively
and directed it toward a subject that could be pursued responsibly. His
detailed review of the ethics application, covering participant safety, dataset
licensing, consent and debriefing, materially improved the protocol. The
discipline of settling those questions before data collection rather than after
has carried through the project as a whole.

Any errors or omissions that remain are my own.

# Declaration on the use of generative AI

Generative AI was used in this project, and its use is declared here in line
with the University's requirement to acknowledge such assistance. Claude Code
(Anthropic) was used as a programming and writing assistant: to write and debug
the data-preparation, training, export and evaluation scripts under `tools/`
and the iOS application under `ios/`; to write the statistical analyses; and to
draft and edit the text of this report.

The research questions, the scope decisions (including the decision not to run
the participant evaluation), the collection of the tape-measured capture set,
every on-device measurement run, and the confirmation of the audit verdicts in
§4.1.7, §4.1.8 and §4.2.1 were carried out by the author. Every numerical result in
this report is produced by a committed script from committed or documented data
and can be regenerated (§3.9). Every reference was checked against its source,
and the record of those checks is Appendix G. The author has reviewed the whole
of the report and takes responsibility for its content.

# List of abbreviations

| Abbreviation | Meaning |
|---|---|
| AGPL | GNU Affero General Public Licence |
| API | application programming interface |
| AP, AP50 | average precision; average precision at an IoU threshold of 0.5 |
| AR | augmented reality |
| ARKit | Apple's augmented-reality framework, which supplies camera frames and LiDAR depth |
| BLV | blind and low vision |
| BVI | blind and visually impaired |
| COCO | Microsoft Common Objects in Context dataset |
| Core ML | Apple's on-device machine-learning runtime |
| DAv2 | Depth-Anything-V2 |
| F1 | harmonic mean of precision and recall |
| fps | frames per second |
| GPL | GNU General Public Licence |
| GPU | graphics processing unit |
| IoU | intersection over union |
| LiDAR | light detection and ranging |
| MAE | mean absolute error |
| mAP, mAP50-95 | mean average precision; its average over IoU thresholds 0.50 to 0.95 |
| MAPE | mean absolute percentage error |
| NMS | non-maximum suppression |
| p95 | 95th percentile |
| RGB | red–green–blue colour image |
| RMSE | root mean square error |
| RQ | research question |
| ViT | vision transformer |
| YOLO | You Only Look Once, a family of single-stage object detectors |

```{=latex}
\tableofcontents
\listoffigures
\listoftables
```

```{=openxml}
<w:p><w:pPr><w:pStyle w:val="TOCHeading"/></w:pPr><w:r><w:t>Contents</w:t></w:r></w:p>
<w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \o "1-3" \h \z \u </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Right-click and choose Update Field to build the table of contents.</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="TOCHeading"/></w:pPr><w:r><w:t>List of Figures</w:t></w:r></w:p>
<w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \h \z \t "Image Caption,1" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Right-click and choose Update Field to build the list of figures.</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="TOCHeading"/></w:pPr><w:r><w:t>List of Tables</w:t></w:r></w:p>
<w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \h \z \t "Table Caption,1" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Right-click and choose Update Field to build the list of tables.</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>
```
