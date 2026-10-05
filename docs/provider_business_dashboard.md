# Provider business dashboard

Home now contains a live business overview below active jobs: 7-, 30- and 90-day reports, custom dates up to 366 days, daily confirmed-payment bars with accessible labels and job drill-down, prior equal-period comparison, payment reminders, service revenue, completed jobs, average invoice, ratings and cancellation rate. No sample revenue is shown.

Confirmed revenue requires status=completed AND providerConfirmedPayment=true. It is grouped by paymentConfirmedAt. Old records without that date fall back to completedAt, then createdAt; records without any date are excluded from dated metrics. Pending totals require completed jobs without provider confirmation and use completion dates. All-date reminders include all such jobs, independent of the filter. These are recorded revenue and unconfirmed invoices, not profit or bank balances. Driver-reported payments do not count as confirmed revenue.

Cancellation rate is cancelled/(completed+cancelled), using their terminal dates in the selected period; active jobs are not included. Ratings use rated completed jobs only. Multi-service jobs count once under their main issue; the revenue is not duplicated across services. All charts use the device's local calendar dates and include both ends of the selected range. Reports do not deduct disputed amounts automatically or process refunds.

Recent service reports monitor only the 10 most recently completed jobs, with live links to the existing dispute screen. Older cases are accessible from History -> Invoice. Each listener is keyed by job ID and is removed when the job leaves that list. This avoids creating a listener for every historical job.

CSV downloads work on web; other platforms copy the CSV to the clipboard and give a filename to save. Export includes job/service/status, invoice amount, completion and confirmation dates and payment classification, without driver names or phone numbers. User text is quoted and guarded against spreadsheet formula injection. Revenue dates use the same legacy fallbacks as the graph. Preserve access to exports according to your team's privacy policy.

The dashboard no longer sets providers online on entry. It observes their saved providerDirectory state; failed availability updates restore the previous switch value. No Firebase rule changes, Cloud Functions, billing upgrade or additional indexes are required for this dashboard.

Validation: provider analytics unit tests cover confirmed vs unconfirmed/cancelled revenue, payment-date attribution, inclusive boundaries, service grouping, empty periods, previous-period comparison and safe CSV formatting. Run flutter test and flutter build web before release.