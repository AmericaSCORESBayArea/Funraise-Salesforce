# Multiple Funraise supporter identities: proof of concept

## Status

This checkout contains a source-level proof of concept for Nonprofit Cloud (NPC).
It has not been deployed because no Salesforce org is authorized in the local
CLI. Do not point it at a production Salesforce or Funraise environment.

## Invariant under test

Two Funraise supporter IDs may identify one Salesforce Person Account:

- `Account.fr_ID__c` remains the latest directly synced Funraise supporter ID.
- `Supporter_Identity__c` stores one row per known Funraise supporter ID, one
  associated email when supplied, and a required lookup to the Person Account.
- NPC relationship syncs resolve an ID against both locations.
- Conflicting ownership or multiple donor matches are logged for manual review;
  the code does not pick an arbitrary record.

`frSupporterResolverTest.twoFunraiseIdsAndGiftsResolveToOnePersonAccount`
exercises a Funraise-shaped supporter REST request and then two gift requests.
It asserts that only the existing Person Account is used, its direct ID advances
to the latest supporter, both identities are retained, and both
`GiftTransaction.DonorId` values point to that Person Account.

## REST path finding

The repository's donor controller declares `@RestResource(urlMapping='/v1/donor')`.
Salesforce therefore exposes it as:

- unmanaged deployment: `/services/apexrest/v1/donor`
- managed package with namespace `funraise`:
  `/services/apexrest/funraise/v1/donor`

The repository README says direct deployment is supported. [Current Funraise
documentation](https://help.funraise.io/en/articles/6137610-connect-salesforce)
describes the integration as open source but recommends the managed AppExchange
package. It does not document which of the two REST paths the Funraise backend
calls. Do not add a second `/funraise/v1/donor` controller until an end-to-end
sandbox test shows that the backend requires the namespaced path for an
unmanaged fork.

## Clean test-org procedure

Use a disposable sandbox or Developer Edition with Person Accounts and NPC Gift
Management enabled. The existing metadata also expects the NPC fields listed in
Funraise's setup instructions.

1. Authorize only the disposable org:

   ```sh
   sf org login web --instance-url https://test.salesforce.com --alias funraise-poc
   ```

2. Compile-check without changing the org:

   ```sh
   sf project deploy start \
     --metadata-dir src \
     --single-package \
     --target-org funraise-poc \
     --dry-run \
     --test-level NoTestRun \
     --wait 30
   ```

3. After reviewing the dry-run result, deploy to that test org and run the POC
   test:

   ```sh
   sf project deploy start \
     --metadata-dir src \
     --single-package \
     --target-org funraise-poc \
     --test-level NoTestRun \
     --wait 30

   sf apex run test \
     --target-org funraise-poc \
     --tests frSupporterResolverTest \
     --result-format human \
     --wait 30
   ```

4. Exercise the unmanaged donor URL with a Salesforce access token before
   connecting Funraise. Then connect a Funraise sandbox and observe the actual
   request path and response. This separates Apex behavior from the unresolved
   backend path assumption.

## Remaining production work

- Decide how to seed existing Person Accounts into identity records before
  enabling the new sync behavior.
- Extend alias resolution to secondary supporter relationships not covered by
  this POC, including campaign fundraisers, registration contacts, and email
  activity.
- Add administrator UI/reporting for ambiguous identity errors and controlled
  alias reassignment.
- Define a supported process for deploying and upgrading the maintained
  `AmericaSCORESBayArea` fork without propagating this change upstream.
