@isTest
public class ContentDocument_UT {
    @isTest static void TestContentDocument(){
        {
            
            ContentVersion cv = new ContentVersion(
                Title = 'Test',
                PathOnClient = 'Test.jpg',
                VersionData = Blob.valueOf('Test Content Data'),
                IsMajorVersion = true,
                Date_Signed__c = system.today(),
                Account_Name__c = 'Test Account'
            );
            insert cv;
            
            // Test INSERT
            ContentVersion contentVersionSelect = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id =: cv.Id LIMIT 1];
            List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];
            System.assertEquals(documents.size(), 1);
            cv.Signer__c = 'Test';
            cv.Type__c = 'MSA with NDA';
            update cv;
            
        }
    }
}