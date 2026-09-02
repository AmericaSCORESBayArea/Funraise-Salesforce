public with sharing class frSupporterResolver {
    public class Result {
        public Account account;
        public Boolean ambiguous = false;
    }

    public static Result resolveAccount(
        String funraiseSupporterId,
        frUtil.Entity sourceType,
        String sourceId,
        Boolean createLogRecord
    ) {
        Result result = new Result();
        if(String.isBlank(funraiseSupporterId)) {
            return result;
        }

        Map<Id, Account> candidates = new Map<Id, Account>();
        List<SObject> canonicalAccounts = Database.query(
            'SELECT Id, fr_ID__c, LastName FROM Account ' +
            'WHERE fr_ID__c = :funraiseSupporterId WITH USER_MODE LIMIT 1'
        );
        for(SObject record : canonicalAccounts) {
            Account account = (Account) record;
            candidates.put(account.Id, account);
        }

        List<Supporter_Identity__c> identities = [
            SELECT Supporter__c, Supporter__r.Id, Supporter__r.fr_ID__c,
                   Supporter__r.LastName
            FROM Supporter_Identity__c
            WHERE Funraise_Supporter_ID__c = :funraiseSupporterId
            WITH USER_MODE
            LIMIT 1
        ];
        for(Supporter_Identity__c identity : identities) {
            if(identity.Supporter__c != null) {
                candidates.put(identity.Supporter__c, identity.Supporter__r);
            }
        }

        if(candidates.size() == 1) {
            result.account = candidates.values().get(0);
        } else if(candidates.size() > 1) {
            result.ambiguous = true;
            logAmbiguousMatch(
                sourceType,
                sourceId,
                funraiseSupporterId,
                'the direct Account ID and identity alias point to different Person Accounts',
                createLogRecord
            );
        }
        return result;
    }

    public static Boolean upsertIdentity(
        Account supporter,
        String funraiseSupporterId,
        String email,
        frUtil.Entity sourceType,
        String sourceId,
        Boolean createLogRecord
    ) {
        return saveIdentity(
            supporter,
            funraiseSupporterId,
            email,
            sourceType,
            sourceId,
            createLogRecord,
            true
        );
    }

    public static Boolean ensureIdentity(
        Account supporter,
        String funraiseSupporterId,
        String email,
        frUtil.Entity sourceType,
        String sourceId,
        Boolean createLogRecord
    ) {
        return saveIdentity(
            supporter,
            funraiseSupporterId,
            email,
            sourceType,
            sourceId,
            createLogRecord,
            false
        );
    }

    private static Boolean saveIdentity(
        Account supporter,
        String funraiseSupporterId,
        String email,
        frUtil.Entity sourceType,
        String sourceId,
        Boolean createLogRecord,
        Boolean overwriteEmail
    ) {
        if(supporter == null || supporter.Id == null || String.isBlank(funraiseSupporterId)) {
            return false;
        }

        List<Supporter_Identity__c> identities = [
            SELECT Id, Supporter__c, Email__c
            FROM Supporter_Identity__c
            WHERE Funraise_Supporter_ID__c = :funraiseSupporterId
            WITH USER_MODE
            LIMIT 1
        ];
        if(!identities.isEmpty() && identities.get(0).Supporter__c != supporter.Id) {
            logAmbiguousMatch(
                sourceType,
                sourceId,
                funraiseSupporterId,
                'the identity alias is already assigned to another Person Account',
                createLogRecord
            );
            return false;
        }

        Supporter_Identity__c identity = identities.isEmpty()
            ? new Supporter_Identity__c(Funraise_Supporter_ID__c = funraiseSupporterId)
            : identities.get(0);
        identity.Supporter__c = supporter.Id;
        if(String.isNotBlank(email) && (overwriteEmail || String.isBlank(identity.Email__c))) {
            identity.Email__c = email;
        }

        try {
            if(identity.Id == null) {
                insert as user identity;
            } else {
                update as user identity;
            }
            return true;
        } catch(Exception ex) {
            if(createLogRecord) {
                frUtil.logException(sourceType, sourceId, ex);
            }
            return false;
        }
    }

    public static void logAmbiguousMatch(
        frUtil.Entity sourceType,
        String sourceId,
        String funraiseSupporterId,
        String detail,
        Boolean createLogRecord
    ) {
        if(createLogRecord) {
            frUtil.logError(
                sourceType,
                sourceId,
                'Ambiguous Funraise supporter identity ' + funraiseSupporterId +
                ': ' + detail + '. Manual review is required.'
            );
        }
    }
}
