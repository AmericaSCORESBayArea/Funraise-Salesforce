@isTest
private class frSupporterResolverTest {
    @isTest
    static void twoFunraiseIdsAndGiftsResolveToOnePersonAccount() {
        if(!frUtil.hasNPCobjects()) {
            return;
        }

        Account supporter = frDonorTest.getTestAccount(false);
        supporter.put('PersonEmail', 'previous@example.com');
        insert supporter;

        insert frSetupController.getPersonAccountDefaults();

        String aliasId = 'supporter-alias-456';
        Map<String, Object> aliasRequest = frDonorTest.getTestRequest();
        aliasRequest.put('id', aliasId);
        aliasRequest.put('firstName', 'Bruce');
        aliasRequest.put('lastName', 'Wayne');
        aliasRequest.put('email', 'alias@example.com');
        aliasRequest.put('address1', '1007 Mountain Drive');
        aliasRequest.put('city', 'Gotham');
        aliasRequest.put('state', 'NJ');
        aliasRequest.put('postalCode', '12345');
        aliasRequest.put('country', 'United States');

        frTestUtil.createTestPost(aliasRequest);
        frWSDonorController.syncEntity();
        frTestUtil.createTestPost(aliasRequest);
        frWSDonorController.syncEntity();

        Account persistedSupporter = [
            SELECT Id, fr_ID__c
            FROM Account
            WHERE Id = :supporter.Id
        ];
        System.assertEquals(
            aliasId,
            persistedSupporter.fr_ID__c,
            'The Account ID should advance to the latest synced supporter identity'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Account],
            'The alias supporter request must not create a duplicate Person Account'
        );

        Map<String, Supporter_Identity__c> identitiesById = new Map<String, Supporter_Identity__c>();
        for(Supporter_Identity__c identity : [
            SELECT Funraise_Supporter_ID__c, Email__c, Supporter__c
            FROM Supporter_Identity__c
            WHERE Supporter__c = :supporter.Id
        ]) {
            identitiesById.put(identity.Funraise_Supporter_ID__c, identity);
        }
        System.assertEquals(2, identitiesById.size());
        System.assertEquals('previous@example.com', identitiesById.get('856').Email__c);
        System.assertEquals('alias@example.com', identitiesById.get(aliasId).Email__c);

        insert frSetupController.getGiftTransactionDefaults();
        createGift('gift-previous', '856');
        createGift('gift-alias', aliasId);

        List<SObject> gifts = Database.query(
            'SELECT Id, DonorId, fr_ID__c FROM GiftTransaction ' +
            'WHERE fr_ID__c IN (\'gift-previous\', \'gift-alias\')'
        );
        System.assertEquals(2, gifts.size());
        for(SObject gift : gifts) {
            System.assertEquals(
                supporter.Id,
                gift.get('DonorId'),
                'Both supporter identities must resolve to the same Person Account'
            );
        }
        frTestUtil.assertNoErrors();
    }

    @isTest
    static void conflictingCanonicalAndAliasIdsAreNotGuessed() {
        if(!frUtil.hasNPCobjects()) {
            return;
        }

        Account directMatch = frDonorTest.getTestAccount(false);
        directMatch.fr_ID__c = 'conflicting-id';
        insert directMatch;

        Account aliased = frDonorTest.getTestAccount(false);
        aliased.fr_ID__c = 'other-canonical-id';
        aliased.put('LastName', 'Different');
        insert aliased;

        insert new Supporter_Identity__c(
            Funraise_Supporter_ID__c = 'conflicting-id',
            Supporter__c = aliased.Id
        );

        frSupporterResolver.Result result = frSupporterResolver.resolveAccount(
            'conflicting-id',
            frUtil.Entity.DONATION,
            'gift-with-conflict',
            true
        );

        System.assertEquals(null, result.account);
        System.assertEquals(true, result.ambiguous);
        Error__c error = [
            SELECT Error__c
            FROM Error__c
            WHERE Funraise_Object_Id__c = 'gift-with-conflict'
            LIMIT 1
        ];
        System.assert(error.Error__c.contains('Manual review is required'));
    }

    private static void createGift(String giftId, String supporterId) {
        Map<String, Object> request = frDonationTest.getTestRequest();
        request.put('id', giftId);
        request.put('donorId', supporterId);
        frTestUtil.createTestPost(request);
        frWSDonationController.syncEntity();
    }
}
