/**
* @author Dayana Daniel
*/

public class NMTNotesDeletionTriggerHandler {
    public static boolean firstRun = true; 
    
    private Boolean m_isExecuting = false;
    private Integer batchSize = 0;
    
    public NMTNotesDeletionTriggerHandler(boolean isExecuting, integer size) {
        this.m_isExecuting = isExecuting;
        this.batchSize = size;
    }
    
    public void onAfterDelete(List<Note> oldNotes){
        List<Id> notesIds = new List<Id>();
        List<Id> notesParentsIds = new List<Id>();
        for (Note note : oldNotes){
            System.debug('note deleted: '+note.Title); 
            notesParentsIds.add(note.ParentId);
            notesIds.add(note.Id);
        }
        System.debug('notes deleted: '+notesIds.size());
        
        List<NAMNoteConversionStatus__c> statuses = [SELECT Id, Status__c, JobId__c, Type__c
                                                  FROM NAMNoteConversionStatus__c 
                                                  LIMIT 1];
        if(!statuses.isEmpty()){
            NAMNoteConversionStatus__c noteConversionStatus = statuses.get(0);
            
            //notes has been converted
            List<ContentDocumentLink> links = [SELECT contentDocument.latestPublishedVersionId
                                               FROM
                                               ContentDocumentLink
                                               WHERE
                                               linkedEntityId in :notesParentsIds
                                               AND
                                               contentDocument.latestPublishedVersion.LegacyNoteConvertedId__c in :notesIds];
            System.debug('count trigger' +links.size());
            
            update noteConversionStatus;
            List<Id> cvs = new List<Id>();
            for(ContentDocumentLink link: links){
                cvs.add(link.contentDocument.latestPublishedVersionId);
            }
            List<ContentVersion> cvsToUpdate = [SELECT LegacyNoteConvertedId__c FROM ContentVersion WHERE id in :cvs];
            for(ContentVersion cv:cvsToUpdate){
                cv.LegacyNoteConvertedId__c = null;
            }
            update cvsToUpdate;
        }
        
    }
    
}