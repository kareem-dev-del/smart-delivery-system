# Global AI Builder's Challenge — SmartDrop submission work

## What existed before the event

SmartDrop already had a Django API, a React administrator dashboard, Flutter customer and courier apps, locker and drawer records, device authentication, one-time pickup QR validation, and order status updates. Those existing capabilities are project context; they are not being presented as work created during the event.

## Work started during the event

### Explainable locker recommendation

Checkout now ranks only online stations with an available drawer large enough for every product in the cart. Its deterministic score combines proximity (50%), compatible free-drawer capacity (30%), and a recent active-device heartbeat (20%). The customer sees the top recommendation and the reasons behind each candidate. A missing or stale device heartbeat lowers the rank and is disclosed; it does not silently remove a station. This is an explainable rules-based decision-support feature, not a trained ML model, and its weights are a prototype that still needs evaluation.

### Locker simulator

The admin dashboard now has a locker simulator page for demonstrating the existing device workflow without physical locker hardware. The simulator authenticates as a provisioned locker device, sends a real device heartbeat, lists orders assigned to that device's station, and calls the existing backend endpoints to confirm courier deposit, authorize pickup from a one-time QR token, and confirm collection.

Drawer movement is visual only. The backend remains responsible for device authorization, locker/order matching, QR validity, idempotency, drawer state, order state, event history, and customer notification. The simulator must be described as a hardware simulation in the submission and demo.

## Run the dashboard simulator

1. Start the backend and admin dashboard using the project's local setup instructions.
2. Sign in to the admin dashboard.
3. Ensure an online locker station has an active provisioned device and at least one drawer.
4. Create a customer order and assign it to that station and a suitable drawer. The order should be in `assigned` status for the deposit step.
5. Open **Locker simulator** from the dashboard navigation. Enter the device username and initial password shown during device provisioning. The password is used only for sign-in; the page keeps the access token in memory and does not persist it.
6. Select the assigned order and run **Simulate courier deposit**. The API changes it to ready for pickup and issues the normal customer notification.
7. In the customer app, open the order and generate its pickup QR. Paste the one-time token into the simulator and scan it. The API validates the token for this device and station and returns the authorized drawer.
8. Confirm the simulated drawer close. The API records collection and updates the order.

The simulator requires an administrator session to list eligible orders and a provisioned device account to perform device operations. Invalid, expired, reused, or wrong-station QR tokens should be rejected by the backend. The simulator does not operate a physical lock, sensor, keypad, or network controller.

### Gemini operations assistant

The admin dashboard now includes an operations assistant powered by Gemini. It can call three fixed, read-only tools: order counts and long-waiting counts, station/drawer capacity, and status for one order public UUID. The backend executes those tools against the live database and returns their evidence beside the model's answer. The model cannot issue commands or change an order, courier, station, or drawer.

For privacy, tool results omit customer names, contact information, and addresses. The free-tier API still receives the operator's question and the operational facts selected by the tools. Keep personal information out of questions. Gemini free-tier content may be used to improve Google's products; disclose this and use non-sensitive demo data. The API key stays in a server environment variable and must never be committed or placed in frontend configuration.

The two-hour wait indicator is a demo threshold, not a service-level agreement. Record representative questions, expected evidence, actual outputs, model failures, and limitations before submission. The default model is `gemini-3.5-flash-lite` and can be changed with `GEMINI_MODEL`; confirm model access in AI Studio before the demo. Provider, model, deterministic recommendation logic, and tools must be named in the Devpost AI disclosure.

## Submission evidence to prepare

- A short before/after explanation that separates the pre-event platform from event work.
- A 2–4 minute recording showing the simulator's real API calls, the AI feature when implemented, and the customer order state changing.
- A small set of successful and failed scenarios, including an invalid QR and an unavailable or undersized locker candidate.
- A concise AI evaluation table with the question, source facts, expected behavior, observed result, and limitations. Initial local observations are recorded below; repeat them against the exact public submission build before filming.
- Accurate disclosures for the simulated locker hardware and AI-assisted development.

### Initial local observations (demo database)

| Feature / prompt | Observed result | Interpretation / limitation |
| --- | --- | --- |
| Locker candidates for product 1 at the demo station coordinates, with a stale device heartbeat | `DEMO-MAADI-001`, 3 compatible free drawers, score 80/100, device readiness unconfirmed | Correctly ranked the only eligible station and disclosed stale device readiness. |
| Same locker query after a fresh device heartbeat | `DEMO-MAADI-001`, 3 compatible free drawers, score 100/100, device recently checked in | The server reflects heartbeat freshness in its explanation and score. Scores are deterministic and relative to returned candidates, not probabilities. |
| Customer app location query from the phone | Only eligible station was 175.7 km away, with 2 compatible drawers and score 30/100 | The app reported the phone's current location result. Verify precise-location permission and the device's reported position before treating this as a recommendation-quality issue. The current phone build shown in the screenshot did not yet display the device-heartbeat line; a follow-up UI change is pending rebuild. |
| "Which lockers have the least available drawer capacity?" | One online station, 3 available drawers out of 3 | Gemini selected the capacity tool and its evidence matched the database. |
| "How many orders are waiting over two hours?" | 0 waiting orders | Correct for the empty order set at that point; two hours is a demo threshold. |
| Specific order UUID status before simulated pickup | `assigned`, locker `DEMO-MAADI-001`, drawer 1 reserved, no courier | Matched the database evidence. |
| Locker simulator: deposit, valid pickup QR, collection confirmation | `assigned` → `ready_for_pickup` → `collected`; drawer returned to `available` | End-to-end state transition succeeded. Physical drawer movement was not tested; it is simulated. |
| Locker simulator: syntactically valid but unknown QR token | HTTP 400 with `Invalid or expired QR token.` | Backend rejected the token without authorizing a drawer. |
| Gemini asked for a syntactically valid UUID absent from the database | `found: false`, with a concise not-found answer | The assistant reported missing evidence instead of inventing an order. |

An order showed an age of 453 minutes and later 837 minutes because `age_minutes` is calculated from its creation timestamp and time passed while the local demo was running. The age is not a refresh indicator. Each assistant question makes a new database-backed request; answers are not live-streamed.

### Human review of AI-assisted development

Codex assisted with implementation and documentation. The team reviewed the simulator against the existing device permissions and order services, then exercised deposit, pickup authorization, collection, and an unknown QR against the local backend. The first browser deposit attempt exposed a CORS rejection of `Idempotency-Key`; the CORS allowlist was corrected and the full simulated lifecycle then succeeded. Gemini's unknown-order response was compared with the known database result (`found: false`). Disclose this development assistance separately from Gemini, which is the AI integrated into the product.

## Devpost draft (review before submission)

**Title:** SmartDrop — AI-Assisted Smart Locker Delivery

**Tagline:** Make parcel delivery easier to coordinate, track, and collect from a nearby eligible locker.

**Project description:** Failed delivery attempts and unclear handoffs make parcel collection inconvenient for customers and difficult to coordinate for operations teams. SmartDrop connects customer ordering, courier workflows, locker assignment, pickup QR authorization, and order tracking in one platform. During this event, we added a Gemini operations assistant that answers admin questions from controlled, read-only database tools, an explainable rules-based locker ranking in checkout, and a software simulator for demonstrating locker-device interactions without physical hardware.

The operations assistant can summarize order workload, inspect station capacity, or look up one order by public UUID. It presents the database evidence used for its answer and cannot change operational records. The checkout ranking combines distance, compatible available drawers, and recent device heartbeat; it is a deterministic heuristic rather than a trained AI model. The simulator uses the real authenticated device API for heartbeat, deposit, QR validation, and collection confirmation, while drawer movement is visual only.

**AI disclosure draft:** The product uses Google's Gemini API (`gemini-3.5-flash-lite`) with function calling. The backend exposes three allowlisted read-only tools for order overview, locker capacity, and a specific order's operational status. It sends no customer names, phone numbers, or addresses to those tools. We manually checked the assistant against known local demo data, including a missing order UUID, and show its supporting evidence and limitations. The free-tier service may use submitted content to improve Google's products; the demo uses non-sensitive sample data. Locker ranking is deterministic business logic and is not described as AI.

**Development disclosure draft:** OpenAI Codex assisted with code and documentation during development. The project authors reviewed the generated changes against existing APIs and permissions, built and manually exercised the dashboard, checked order-state results against the database, and corrected a CORS integration issue discovered during the simulator walkthrough. Existing SmartDrop functionality is identified separately from work completed for this event.

**Hardware disclosure:** No physical locker is connected. Drawer opening and closing in the demo are simulated; backend authorization, QR validation, and order-state updates are real local API operations.

**Team roster:** Confirm the public Devpost roster before submission. Each listed member must satisfy the event requirements. Each participant must separately submit the private contact form.

## Three-minute demo outline

| Time | Show and say |
| --- | --- |
| 0:00–0:20 | State the customer and operations problem: delivery handoffs are hard to coordinate and collection status is unclear. |
| 0:20–0:45 | Show the existing SmartDrop customer checkout and clearly point out the event-added locker ranking and its distance, capacity, score, and device-readiness explanation. |
| 0:45–1:20 | Ask the operations assistant a capacity or order-status question. Show Gemini's answer beside the actual tool evidence. |
| 1:20–2:20 | Walk through the locker simulator: device heartbeat, courier deposit, customer pickup QR authorization, and collection confirmation. Show the order reaching `collected`. State that drawer motion is simulated. |
| 2:20–2:40 | Show a rejected invalid QR and an unknown order query. Explain how the system handles each. |
| 2:40–3:00 | Recap what was built during the event, distinguish Gemini from the rules-based ranking, and disclose the hardware simulation and free-tier data limitation. |

Record only after rebuilding the latest mobile UI and confirming the location result and device-readiness line on the exact demo setup. Keep the API key out of screen recordings, source code, browser network screenshots, and the Devpost page.

## Current completion status

- [x] Isolated work on `feat/global-ai-builders-challenge` from `main`.
- [x] Added an explainable checkout locker-ranking prototype with distance, compatible capacity, and device-heartbeat evidence.
- [x] Added a dashboard simulator that uses the existing authenticated device API.
- [x] Added a read-only Gemini operations assistant with database-backed tools.
- [x] Exercised three assistant questions and one complete simulated locker order lifecycle against local demo data; observations are recorded above.
- [x] Recorded two negative cases: unknown QR rejection and missing order UUID reported as not found.
- [x] Configure the Gemini API key in the ignored local backend environment; the key is not in the repository.
- [ ] Add the Gemini API key to a contest deployment environment only if we choose to host the demo publicly.
- [ ] Repeat evaluation on the exact public submission build and capture evidence.
- [ ] Rebuild and capture the final customer-app recommendation card after its last layout change.
- [ ] Review the full end-to-end demo and repeat failure scenarios on the exact submission build.
- [ ] Finish the Devpost description, disclosures, and 2–4 minute video.
