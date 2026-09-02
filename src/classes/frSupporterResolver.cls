public with sharing class frSupporterResolver {
    public static Account resolveAccount(String funraiseSupporterId) {
        if(String.isBlank(funraiseSupporterId)) {
            return null;
        }

        List<Supporter_Identity__c> identities = [
            SELECT Supporter__c, Supporter__r.Id, Supporter__r.LastName
            FROM Supporter_Identity__c
            WHERE Funraise_Supporter_ID__c = :funraiseSupporterId
            WITH USER_MODE
            LIMIT 1
        ];
        return identities.isEmpty() ? null : identities.get(0).Supporter__r;
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
            createLogRecord
        );
    }

    private static Boolean saveIdentity(
        Account supporter,
        String funraiseSupporterId,
        String email,
        frUtil.Entity sourceType,
        String sourceId,
        Boolean createLogRecord
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
        if(String.isNotBlank(email)) {
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
