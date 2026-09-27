# Chapter 2 — source verification record

Checked 15 September 2026 against the primary sources. Seven figures were
carried from the earlier draft unverified; this records what each check found.

## Verified correct — no change needed

| Claim | Source | Result |
|---|---|---|
| Okolo et al. 91.70 % average accuracy over nine obstacles | JDR 2025, abstract + Table 1 | **Confirmed.** Table 1's nine values average to exactly 91.70 |
| PathFinder: 15 BVI participants, 73 % learned in under a minute, 80 % praised accuracy/responsiveness | Das et al. 2025, abstract | **Confirmed**, all three figures |
| Tokmurziyev et al. 81.3 % | LLM-Glasses, abstract | **Confirmed** as a figure |
| Vis-Assist: 19 object classes | Dede and Gumus 2025 | **Confirmed** |
| Crivello et al.: 75 papers | IJHCI 2026 | **Confirmed** |

## Corrections required

### 1. Khilnani and Devesh — the quoted mAP is the flattering half of a pair

The draft says "71.7 % mAP at IoU 0.5". The abstract reports **"a mAP of 53.4 %
and an AP50 of 71.7 %"**. Both are real; quoting only 71.7 % takes the higher
of two reported numbers without saying so.

This matters beyond pedantry. Chapter 4 reports pooled **mAP50-95** of 0.170.
The comparable figure from this paper is **53.4 %**, not 71.7 % — and even that
comparison is across different corpora. Quote both, and never place 0.170
beside 71.7 % as though they measure the same thing.

The framework is also **RT-DETRv3-R50** specifically, not "RT-DETR" generally.

### 2. Tokmurziyev et al. — what the 81.3 % measures

The draft describes it as accuracy "interpreting directional vibration cues
delivered to the temples". The paper reports **"recognition of 13 haptic
patterns with an average recognition rate of 81.3 %"**. Thirteen distinct
patterns is a stronger result than directional cues and should be stated as
such — it supports the same argument better.

### 3. Okolo et al. — the platform description understates it substantially

The draft describes the system as requiring "an external ultrasonic unit rather
than relying on hardware already present in a consumer handset". The paper
describes a **Raspberry Pi 4 smart stick** carrying a camera, ultrasonic
sensor, moisture sensor, accelerometer/gyroscope, vibration module and speaker,
**plus** a separate Android application ("Here We Go") for GPS navigation. The
abstract states the mobile application "uses voice and audio only"; the tactile
channel lives on the stick.

So it is not a smartphone system with a sensor bolted on. It is a dedicated
embedded device plus a phone app. The contrast with a smartphone-only prototype
is considerably sharper than the draft claims.

### 4. Okolo et al. — two findings that strengthen this thesis

**The nine "obstacles" are COCO classes**: person, car, bus, truck, chair, TV,
couch, bottle, refrigerator. Three are outdoor vehicles, and **none is a door,
a step, a stair or a pole**. This is direct evidence for §3.3.1's argument that
COCO cannot support the indoor classes that carry the highest consequence on
contact — the closest comparable system demonstrates the limitation rather than
escaping it.

**Distance accuracy is reported as a boolean.** Table 1's "Distance accuracy"
column reads `True` for all nine objects. No error magnitude, no units, no
ground truth. This is the strongest available support for Objective 2's gap
claim: the closest system in the corpus does not quantify distance error at
all.

The "accuracy" figures are also per-object detection accuracy, not mAP. Do not
compare them against Chapter 4's mAP50-95 under any circumstances.

## Removed rather than corrected

### 5. Crivello et al. — the 44 % has been taken out of the chapter

The draft stated that 44 % of the 75 surveyed systems include usability
testing, and Domain D's argument rested on it, in four places.

Publicly available text from the survey attaches 44 % to a different finding
entirely: **"44 % of the navigation solutions analyzed require a preliminary
training phase before deployment"** — a statement about data collection and
model training, not evaluation. Two different claims sharing one number is
exactly how a figure gets attached to the wrong sentence.

**Attempts made to verify (15 Sept 2026), all unsuccessful:** Taylor & Francis
full text and PDF endpoints (403, Cloudflare — the article is hybrid open
access under CC-BY-NC-ND, so this is bot blocking rather than a paywall);
`curl` with a browser user agent (403); the CNR IRIS institutional repository
(403); Semantic Scholar (metadata only, no abstract, `openAccessPdf` points
back to the blocked DOI); and a related CEUR paper by the same group
(Belli et al., 2024), which turns out to be a position paper that explicitly
"does not aim to be an exhaustive or systematic review" and carries no
comparable statistic.

**Resolution taken.** Rather than leave a probably-misattributed figure in the
chapter, Domain D now rests on the survey's own stated headline findings, which
are visible in the abstract: **limited focus on inclusivity factors — usability,
accessibility, user experience and co-design** — alongside the absence of
seamless indoor/outdoor solutions and a gap between proposed systems and
technological readiness. That supports the same argument in the authors' own
framing and cannot be misattributed. The quantitative weight of §2.5.4 now
comes from the individual studies instead: Das et al. (15 participants),
Chaudary et al. (11 plus one carer), Dede and Gumus (4).

**Optional, if you get access.** Open DOI `10.1080/10447318.2026.2643358`
through the university library and search the PDF for `44` and for
`usability`. One question: does the survey report a percentage of systems that
performed usability evaluation? If it does, tell me the figure and I will put
it back — a number is stronger than a qualitative claim. If it does not, the
chapter is already correct as it stands and nothing further is needed.

## Resolved after the first pass

Both figures initially unreachable were obtained on 15 September via the
Semantic Scholar metadata API, which carries the ACM abstract in full.

### Zhao and Zhang (2023) — all figures confirmed, and two improvements found

96.3 % recognition at 8 fps within 8 m, and 85 % at complex intersections:
**both confirmed**. Two details in the abstract were not in the draft and
change how the citation should be used.

The 85 % is measured at intersections **30 m wide** — nearly four times the 8 m
range at which 96.3 % was established. The drop therefore conflates scene
complexity with operation beyond the validated range and cannot cleanly
evidence either. §2.5.1 now says so.

The paper also reports **94 % in low-light conditions at the same 8 m range**.
That is a controlled single-variable degradation of roughly two percentage
points, and it is directly comparable to this project's own bright/dim capture
conditions. It is the more useful of the two comparisons and is now cited as
such.

The system is also **outdoor** — traffic signs, tactile paving, intersections —
which §2.5.1 now states explicitly.

### Dede and Gumus (2025) — confirmed

**Four participants**, across two experiment types, measuring task completion
time. 19 object classes confirmed separately. Springer withholds the abstract
from indexing APIs and the PDF is closed; the figures were confirmed from
indexed descriptions of the evaluation.

---

## Summary

Of seven figures carried unverified from the earlier draft: **six confirmed**
(three of them with corrections to how they were described), and **one removed**
— the Crivello 44 %, which could not be verified and appears to belong to a
different claim. No unverified figure remains in Chapter 2.

## Figure 2.1 — regenerated 15 September 2026

`figures/figure_2_1_review_structure.svg`. The figure carried into the draft
came from an earlier version and contradicted its own chapter: it stated 18
sources with a 9 arXiv / 6 journal / 3 conference split where §2.2, §2.4 and
Table 2.1 state 14 and 6/6/2, and it labelled the gap mapping as Table 2.1 when
it is Table 2.2. Both corrected. The figure now also records that Objective 4
was not carried out, so it cannot drift out of step with §1.5.

This record lives here rather than in Chapter 2 because it is a drafting
correction, not thesis content.

## Table 2.2 — Domain C gap reassigned to Objective 4

The earlier draft assigned the Domain C gap (isolating the haptic channel from
audio) to Objective 3. Objective 3 is the build; the controlled comparison is
Objective 4. Table 2.2 and Figure 2.1 both now say Objective 4, and the note
that recorded the discrepancy has been removed from Chapter 2 — it described a
correction that had already been made.

## Chaudary et al. (2023) — kept in Domain C

A drafting note proposed moving this paper from Domain C (feedback design) to
Domain D (evaluation methodology), on the grounds that it is primarily a
usability study. Resolved as **keep in C**: the paper is discussed
substantively in both §2.5.3 and §2.5.4, so moving only the table row would
have created a fresh inconsistency rather than removed one, and Table 2.1
records each paper's *primary* contribution — which here is the teleguidance
feedback system, with the meCUE questionnaire method cited separately in §2.5.4.
The table caption now says so explicitly.
