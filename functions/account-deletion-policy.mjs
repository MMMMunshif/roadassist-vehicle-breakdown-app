export function deletionBlockers(jobs) {
  return jobs.filter(job => !['completed', 'cancelled'].includes(job.status) ||
    (job.status === 'completed' && job.providerConfirmedPayment !== true) ||
    (job.hasDispute && !['resolved', 'dismissed'].includes(job.complaintStatus)));
}
