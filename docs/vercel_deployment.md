# Vercel deployment

The GitHub Actions workflow builds the Flutter web app and deploys it together
with the existing `api/` functions to the linked Vercel project. A push to
`develop` starts a production deployment; the workflow can also be started
manually from the repository's **Actions** tab.

## Configure GitHub Actions

Add these repository secrets under **Settings → Secrets and variables →
Actions**:

- `VERCEL_TOKEN`: create a token in Vercel under **Account Settings → Tokens**.
- `VERCEL_ORG_ID`: copy the `orgId` value from the local
  `.vercel/project.json` file.
- `VERCEL_PROJECT_ID`: copy the `projectId` value from the same file.

Keep `.vercel/project.json` local; do not commit it. The workflow creates a
temporary linked-project file from the GitHub secrets.

## Configure Vercel API environment variables

The deployed API functions require these variables in the Vercel project's
**Settings → Environment Variables**:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `GMAIL_USER`
- `GMAIL_APP_PASSWORD`

Set them for the **Production** environment. Keep the private key and mail
password in Vercel's encrypted environment-variable settings; never put them
in the repository.

After configuring the secrets and environment variables, merge the workflow
into `develop` or manually run **Deploy Flutter web to Vercel** from the
Actions tab. Confirm that the production deployment is ready and that
`vehiclebreakdownapp.vercel.app` is assigned under Vercel **Settings → Domains**.
