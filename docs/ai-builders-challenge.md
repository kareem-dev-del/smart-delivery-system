# Global AI Builder's Challenge — SmartDrop submission work

## What existed before the event

SmartDrop already had a Django API, a React administrator dashboard, Flutter customer and courier apps, locker and drawer records, device authentication, one-time pickup QR validation, and order status updates. Those existing capabilities are project context; they are not being presented as work created during the event.

## Work started during the event

### Explainable locker recommendation

Checkout now ranks only online stations with an available drawer large enough for every product in the cart. Its deterministic score combines proximity (50%), compatible free-drawer capacity (30%), and a recent active-device heartbeat (20%). The customer sees the top recommendation and the reasons behind each candidate. A missing or stale device heartbeat lowers the rank and is disclosed; it does not silently remove a station. This is an explainable rules-based decision-support feature, not a trained ML model, and its weights are a prototype that still needs evaluation.

### Locker simulator

The admin dashboard now has a locker simulator page for demonstrating the existing device workflow without physical locker hardware. The simulator authenticates as a provisioned locker device, sends a real device heartbeat, lists orders assigned to that device's station, and calls the existing backend endpoints to confirm courier deposit, authorize pickup from a one-time QR token, and confirm collection.

Drawer movement is visual only. The backend remains responsible for device authorization, locker/order matching, QR validity, idempotency, drawer state, order state, event history, and customer notification. The simulator must be described as a hardware simulation in the submission and demo.

## Record the complete demo journey

1. Start the backend and admin dashboard using the project's local setup instructions. Confirm that the online demo station has an active device and a compatible available drawer.
2. In the customer app, sign in as `demo-customer`, add a product to the cart, choose the demo locker at checkout, and place the order. Checkout reserves a compatible drawer and creates an `assigned` order.
3. In the customer app, sign out and sign in as `demo-courier`. Open **Courier hub**, start the shift, and leave the hub open so the task can refresh.
4. In the admin dashboard, open **Orders**, open the new order, choose the on-shift demo courier under **Courier assignment**, and save. The courier task appears in **My deliveries**; opening it shows the locker address, drawer, parcel contents, and directions.
5. In the customer app, sign out of the courier account and return to `demo-customer`. Open **My Orders**, tap the order, and use **Track order** to show its assigned state.
6. In the dashboard, open **Locker simulator** and connect with the provisioned device account. Select the order and run **Simulate courier deposit**. This represents the courier placing the parcel into the assigned drawer; the authenticated device API changes the order to `ready_for_pickup` and creates the customer notification.
7. Return to the customer app's tracking page. Refresh if needed, press **Generate pickup QR**, and show the one-time code. It expires after ten minutes. For the browser simulator, copy its token and paste it into **Customer pickup QR token**.
8. In the simulator, scan the token and confirm the simulated drawer close. The backend validates the token, records collection, releases the drawer, and changes the order to `collected`. The tracking page refreshes automatically; refresh the admin Orders page to show the final state.

The customer app routes to **Courier hub** automatically when a courier account signs in. There is no separate courier web page. The courier app shows the assigned task and destination; the locker simulator represents the device confirmation because no physical locker is connected. Never describe drawer motion as real hardware operation.

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
| 0:00–0:20 | Introduce the delivery coordination problem and SmartDrop. |
| 0:20–0:45 | Place a customer order and show the eligible locker recommendation. |
| 0:45–1:10 | Assign the on-shift courier in the dashboard, then show the order in Courier hub with the station and drawer. |
| 1:10–1:35 | Use Locker simulator to confirm deposit; show the customer's tracking status change to ready for pickup. State that drawer motion is simulated. |
| 1:35–2:05 | Generate the customer pickup QR, authorize it in the simulator, and confirm collection. Show `collected`. |
| 2:05–2:40 | Ask Gemini a live operational question and show the evidence cards. |
| 2:40–3:00 | Recap the new features and disclose the rules-based recommendation and simulated hardware. |

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
