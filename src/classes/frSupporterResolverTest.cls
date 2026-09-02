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
        insert new frSupporter_Identity__c(
            Funraise_Supporter_ID__c = '856',
            Email__c = 'previous@example.com',
            Supporter__c = supporter.Id
        );

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

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Account],
            'The alias supporter request must not create a duplicate Person Account'
        );

        Map<String, frSupporter_Identity__c> identitiesById = new Map<String, frSupporter_Identity__c>();
        for(frSupporter_Identity__c identity : [
            SELECT Funraise_Supporter_ID__c, Email__c, Supporter__c
            FROM frSupporter_Identity__c
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
    static void identityRowIsRequiredForResolution() {
        if(!frUtil.hasNPCobjects()) {
            return;
        }

        Account supporter = frDonorTest.getTestAccount(false);
        insert supporter;

        System.assertEquals(
            null,
            frSupporterResolver.resolveAccount('conflicting-id'),
            'An Account without an identity row must not resolve'
        );

        insert new frSupporter_Identity__c(
            Funraise_Supporter_ID__c = 'conflicting-id',
            Supporter__c = supporter.Id
        );

        System.assertEquals(
            supporter.Id,
            frSupporterResolver.resolveAccount('conflicting-id').Id,
            'The identity row must be authoritative'
        );
    }

    private static void createGift(String giftId, String supporterId) {
        Map<String, Object> request = frDonationTest.getTestRequest();
        request.put('id', giftId);
        request.put('donorId', supporterId);
        frTestUtil.createTestPost(request);
        frWSDonationController.syncEntity();
    }
}
