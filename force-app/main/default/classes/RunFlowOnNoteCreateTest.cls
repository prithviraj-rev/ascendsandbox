@IsTest
public class RunFlowOnNoteCreateTest {

    @IsTest
    static void testContentDocumentLinkCreatesAccountLink() {

        // Create Account + Opportunity
        Account acct = new Account(
            Name = 'Test Account',
            BillingState = 'IA'
        );
        insert acct;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = System.today(),
            AccountId = acct.Id
        );
        insert opp;

        // Create a ContentVersion representing a Note (.snote)
        ContentVersion cv = new ContentVersion(
            Title = 'MyNote.snote',
            PathOnClient = 'MyNote.snote',
            VersionData = Blob.valueOf('Test Notes'),
            Origin = 'H'
        );
        insert cv;

        // Get the related ContentDocument
        ContentDocument doc = [
            SELECT Id
            FROM ContentDocument
            WHERE LatestPublishedVersionId = :cv.Id
            LIMIT 1
        ];

        // Insert the initial Opportunity link
        insert new ContentDocumentLink(
            ContentDocumentId = doc.Id,
            LinkedEntityId = opp.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        // Query all links and check for the Account
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :doc.Id
        ];

        Boolean hasAccountLink = false;
        Boolean hasOppLink = false;

        for (ContentDocumentLink l : links) {
            if (l.LinkedEntityId == acct.Id) hasAccountLink = true;
            if (l.LinkedEntityId == opp.Id) hasOppLink = true;
        }

        System.assert(hasOppLink, 'Original Opportunity link should exist.');
        System.assert(hasAccountLink, 'Account link should be created by the trigger.');
    }



    @IsTest
    static void testNonSnoteFilesAreIgnored() {

        // Create Account + Opportunity
        Account acct = new Account(
            Name = 'Test Account 2',
            BillingState = 'IA'
        );
        insert acct;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp 2',
            StageName = 'Prospecting',
            CloseDate = System.today(),
            AccountId = acct.Id
        );
        insert opp;

        // Create NON-snote version
        ContentVersion cv = new ContentVersion(
            Title = 'RegularFile.pdf',
            PathOnClient = 'RegularFile.pdf',
            VersionData = Blob.valueOf('Test File'),
            Origin = 'H'
        );
        insert cv;

        // Get the related ContentDocument
        ContentDocument doc = [
            SELECT Id
            FROM ContentDocument
            WHERE LatestPublishedVersionId = :cv.Id
            LIMIT 1
        ];

        // Insert the initial Opportunity link
        insert new ContentDocumentLink(
            ContentDocumentId = doc.Id,
            LinkedEntityId = opp.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        // Query all links and check absence of Account link
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :doc.Id
        ];

        Boolean hasAccountLink = false;
        Boolean hasOppLink = false;

        for (ContentDocumentLink l : links) {
            if (l.LinkedEntityId == acct.Id) hasAccountLink = true;
            if (l.LinkedEntityId == opp.Id) hasOppLink = true;
        }

        System.assert(hasOppLink, 'Original Opportunity link should exist.');
        System.assert(!hasAccountLink, 'No Account link should be created for non-snote files.');
    }
}