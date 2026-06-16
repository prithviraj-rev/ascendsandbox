public class NMTMigratorBatchHelper {
    /**
* @description Creates a ContentNote from a ContentVersion with a .snote extension
@param notes to be converted
@param objectName: The type of the parent of the notes that we are migrating
@return List<NAMMigrationResults>: 
first add the errors (if any) when insert the content versions
second add the error (if any) from the call to the method to create content document links
finally add success if any content version was insert successfully and no errors were return in
the creation of content document links
*/
    public static List<NAMMigrationResults> migrateToContentNoteUsingContentVersion(List<Note> notes, String objectName) {
        List<NAMMigrationResults> migrationResultsList = new List<NAMMigrationResults>();
        if(notes.size() > 0){
            List<ContentVersion> cvsToCreate = new List<ContentVersion>();
            
            Boolean ownerIsActive = NAMConfigs.getEnableOwner();
            Boolean ownerFromToIsActive = NAMConfigs.getEnableOwnerFromTo();
            String owner;
            String ownerFrom;
            String ownerTo;
            if(ownerIsActive){
                owner = NAMConfigs.getOwner();
            }
            if(ownerFromToIsActive){
                ownerFrom = NAMConfigs.getOwnerFrom();
                ownerTo = NAMConfigs.getOwnerTo();   
            }
            for(Note oldNote :notes){
                
                cvsToCreate.add(createContentVersion(oldNote, ownerIsActive, owner, ownerFromToIsActive, ownerFrom, ownerTo));
                
            }
            
            Integer idsSuccess = 0;
            Integer counter = 0;
            List<Id> notesFailUpdate = new List<Id>();
            List<Note> notesSuccess = new List<Note>(); 
            List<ContentVersion> cvSuccess = new List<ContentVersion>(); 
            //map Id of the legacy note with the created ContentVersion (new Note)
            Map<Id, ContentVersion> mapLegacyNoteWithCV = new Map<Id, ContentVersion>();
            //map Id of the contentversion (new note) with the legacy Note 
            Map<Id, Note> mapCVIdWithNote = new Map<Id, Note>();
            if(Schema.sObjectType.ContentVersion.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.LegacyNoteConvertedId__c.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.Title.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.VersionData.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.FirstPublishLocationId .isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.PathonClient.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.LegacyNoteConvertedParentId__c.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.LegacyNoteConvertedOwnerId__c.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.OwnerId.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.CreatedById.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.CreatedDate.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.LastModifiedById.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.LastModifiedDate.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.SharingPrivacy.isCreateable()
               &&Schema.sObjectType.ContentVersion.fields.Origin.isCreateable()){
                   Database.SaveResult[] srList = Database.insert(cvsToCreate, false);
                   for (Database.SaveResult sr : srList) {
                       if (sr.isSuccess()) {
                           idsSuccess++;
                           notesSuccess.add(notes.get(counter));
                           cvSuccess.add(cvsToCreate.get(counter));
                           mapLegacyNoteWithCV.put(notes.get(counter).Id, cvsToCreate.get(counter));
                           mapCVIdWithNote.put(cvsToCreate.get(counter).Id, notes.get(counter));
                       }else{
                           for(Database.Error err : sr.getErrors()) {
                               migrationResultsList.add(new NAMMigrationResults(String.valueOf(notes.get(counter).Id), '', NAMUtils.isPrivateResult(notes.get(counter).isPrivate), NAMMigrationResults.StatusEnum.ERROR, err.getStatusCode() + ': '+ err.getMessage()));
                               if(err.getStatusCode().equals(System.StatusCode.STORAGE_LIMIT_EXCEEDED)){
                                   throw new NAMStorageException(migrationResultsList);
                               }
                           }                        
                       }    
                       counter++;
                   }
               }
            //for each success note converted get the ncessary data to create the CDL
            List<ID> cvIds = new List<ID>();
            for(ContentVersion cv :cvSuccess){
                cvIds.add(cv.id);
            }
            
            
            Map<ID, ContentVersion> contentVersionMap = new Map<ID, ContentVersion>([
                SELECT
                id,
                contentDocumentId,
                LegacyNoteConvertedParentId__c
                FROM
                ContentVersion
                WHERE
                id IN :cvIds
            ]);
            
            //We don't need create CDL  since we are setting up ContentVersion.FirstPublishLocationId field
            if(idsSuccess > 0){                                
                //lists the migrated notes in the email
                for(Note note : notesSuccess){
                    Id legacyNoteId = String.valueOf(note.Id);
                    
                    //mapLegacyNoteWithCV does not contain contentDocumentId
                    ContentVersion cv = mapLegacyNoteWithCV.get(note.Id);
                    
                    ContentVersion cvConverted =contentVersionMap.get(cv.Id);
                    Id convertedNoteId = null;
                    if(cvConverted!=null){
                        convertedNoteId = cvConverted.contentDocumentId;
                    }
                    NAMMigrationResults result = new NAMMigrationResults(legacyNoteId, convertedNoteId, NAMUtils.isPrivateResult(note.isPrivate), NAMMigrationResults.StatusEnum.SUCCESS, '');
                    migrationResultsList.add(result);
                }                           
                
            }
            
        }
        return migrationResultsList;
    }
    
    /*
* @description Create a ContentVersion from a Note
*/
    private static ContentVersion createContentVersion(Note oldNote, Boolean ownerIsActive, String owner, Boolean ownerFromToIsActive, String ownerFrom, String ownerTo)
    {
        String noteBody = NAMUtils.cleanUpNoteBody(oldNote.body);
        ContentVersion cv = new ContentVersion();
        if(Schema.sObjectType.ContentVersion.fields.LegacyNoteConvertedDate__c.isCreateable()
           && Schema.sObjectType.ContentVersion.fields.LegacyNoteConvertedLastModifiedDate__c.isCreateable()){
               
               // data fields
               cv.title = oldNote.title;
               cv.versionData = Blob.valueOf(noteBody);
               cv.pathOnClient = oldNote.title + '.snote';
               cv.LegacyNoteConvertedId__c = oldNote.id;
               cv.LegacyNoteConvertedParentId__c = oldNote.parentId;
               cv.LegacyNoteConvertedOwnerId__c = oldNote.parentId;
               
               if(ownerFromToIsActive && String.valueOf(oldNote.ownerId).startsWith(ownerFrom)){
                   cv.ownerId = ownerTo;
                   cv.createdById = ownerTo;
               } else if (ownerIsActive) {
                   cv.ownerId = owner;
                   cv.createdById = owner;
               } else{
                   cv.ownerId = oldNote.ownerId;
                   cv.createdById = oldNote.ownerId;
               }
               cv.createdDate = oldNote.createdDate;
               cv.lastModifiedById = oldNote.lastModifiedById;
               cv.lastModifiedDate = oldNote.lastModifiedDate;
               DateTime dateOld = oldNote.CreatedDate;
               DateTime dateOldLastModifiedDate = oldNote.lastModifiedDate;
               cv.LegacyNoteConvertedDate__c = Date.newInstance(dateOld.year(), dateOld.month(), dateOld.day());
               cv.LegacyNoteConvertedLastModifiedDate__c = Date.newInstance(dateOldLastModifiedDate.year(), dateOldLastModifiedDate.month(), dateOldLastModifiedDate.day());
               /*
* "Setting FirstPublishLocationId allows you to create a file and share it with an initial 
* record/group in a single transaction"
* ContentDocumentLink will create automatically by Salesforce
*/
               cv.FirstPublishLocationId = oldNote.parentId;
               cv.Origin = 'H'; 
               if(oldNote.IsPrivate){
                   cv.SharingPrivacy = 'P';
               }
               
           } else {
               system.debug('ContentVersion - createContentVersion access / You have insufficient permission to insert a ContentVersion');
               throw new NAMForbiddenException('You have insufficient permission to insert a ContentVersion');
               
           }
        return cv;
    }
}