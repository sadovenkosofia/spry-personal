# Lab 9, Part 3: cost of Spry's core on Google Cloud

Prices are the on-demand list prices from the lab handout (USD, us-central1, 730 hours a
month, checked by the lecturer on 5 November 2026, no tax). I did not re-check them in the
calculator. The AWS column is not filled in here: copy it from your own Lab 4 table.

## Reference: nobody uses it for a month

| Piece | AWS (Lab 4, Stage 2) | Google Cloud (my choice) |
|---|---|---|
| Frontend + CDN + HTTPS | copy from Lab 4 | Firebase Hosting free plan: $0 |
| API | copy from Lab 4 | Cloud Run scaled to zero: $0 |
| Database compute | copy from Lab 4 | Cloud SQL `db-f1-micro`, running: 730 h x $0.0105 = $7.67 |
| Database storage | copy from Lab 4 | 10 GB SSD x $0.17 = $1.70 |
| Registry, secrets, logs | copy from Lab 4 | within the free tier (0.5 GB, 6 secret versions) |
| **Total** | copy from Lab 4 | **$9.37**, or **$1.70** with the instance stopped |

Free-tier assumptions: Cloud Run 2M requests, 180,000 vCPU-seconds and 360,000 GiB-seconds a
month; Artifact Registry 0.5 GB; Secret Manager 6 active versions (I use 2).

## Four traffic profiles (Google Cloud side)

Cloud SQL is stopped outside the hours listed; the stopped instance still pays for storage.

| Profile | Cloud SQL running | Cloud SQL compute | Storage | Cloud Run | Total, Cloud SQL stopped outside use | Total, Cloud SQL always on | Total, Firestore instead |
|---|---|---|---|---|---|---|---|
| Nobody | 0 h | $0.00 | $1.70 | $0 | **$1.70** | $9.37 | $0 |
| Class demos (10 x 2 h) | 20 h | 20 x $0.0105 = $0.21 | $1.70 | $0 | **$1.91** | $9.37 | $0 |
| Office hours (8 h x 22 days) | 176 h | 176 x $0.0105 = $1.85 | $1.70 | $0 | **$3.55** | $9.37 | $0 |
| Busy around the clock | 730 h | $7.67 | $1.70 | $0 if under the free tier | **$9.37** | $9.37 | $0 while under 50,000 reads a day, then $0.03 per 100,000 |

Cloud Run stays at $0 in the first three profiles because student traffic is far below
2M requests and 180,000 vCPU-seconds. Worst case for the last profile, if one container were
actually busy all month at 1 vCPU and 512 MiB: (2,628,000 - 180,000) x $0.000024 = $58.75 for
CPU plus (1,314,000 - 360,000) x $0.0000025 = $2.39 for memory, about $61. Real traffic is
nowhere near this; it is the upper bound.

## Which cloud is cheaper, and which line decides it

To fill in after copying the AWS numbers from Lab 4. With the reference AWS total of about
$0.30 for an idle month, AWS wins every profile where nothing keeps Aurora awake, and the
deciding line is **database compute**: Aurora pauses, Cloud SQL runs and bills until you stop
it, Firestore has nothing to pause. Stopping the Cloud SQL instance closes most of the gap in
the light profiles ($1.70 to $3.55), but storage is billed while stopped, so it cannot reach
AWS's pause-to-near-zero.

## The equivalent trap on the GCP side

On AWS the trap is something keeping Aurora awake. On GCP the trap is that **Cloud SQL never
pauses**: forget to stop it and every profile costs $9.37. Two related traps: a stopped
instance still bills its 10 GB of storage, and Cloud Run `min instances` above 0 stops it from
scaling to zero.
