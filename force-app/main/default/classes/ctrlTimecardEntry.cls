public class ctrlTimecardEntry {
  @RemoteAction
  public static Contact[] getResources() {
    return [SELECT Id, Name, Email FROM Contact WHERE RecordType.Name = 'Resource' AND Status__c = 'Active' AND External_Resource__c = FALSE];
  }
  
  private static SFDC_Assignment__c[] getAssignments( String resource, date sDate, date eDate ) {
    SFDC_Assignment__c[] ats = Database.query('SELECT Name, Start_Date__c, End_Date__c, Projects__c, Client_Rate__c, Projects__r.Id, Projects__r.Name '
      + 'FROM SFDC_Assignment__c '
      + 'WHERE (Start_Date__c <> NULL) AND (End_Date__c <> NULL) AND Resource__c = \'' + resource + '\'');
    
    // now filter assignments by date
    for(Integer i = 0; i < ats.size(); i++) {
      SFDC_Assignment__c a = ats.get(i);
      date sd = a.Start_Date__c,
           ed = a.End_Date__c;
      
      if( sd > eDate || ed < sDate ) {
        // assignment starts after end of query range, or
        // assignment ends before start of query range,
        // then don't show it
        ats.remove(i--); // decrement index to account for decrease in size
      }
    }
    
    return ats;
  }
  
  @RemoteAction
  public static JoinedAssignmentLineItem[] getLineItems( String resource, date sDate, date eDate ) {
    SFDC_Assignment__c[] assignments = getAssignments(resource, sDate, eDate);
    List<JoinedAssignmentLineItem> items = new List<JoinedAssignmentLineItem>();
    
    for(SFDC_Assignment__c a : assignments) {
      for(Project_Line_Item__c pli : Database.query('SELECT Id, Name FROM Project_Line_Item__c WHERE Project__c = \'' + a.Projects__c + '\'')) {
        items.add(new JoinedAssignmentLineItem(a, pli));
      }
    }
    
    return items;
  }
  
  public class JoinedAssignmentLineItem {
    String aId,
           aName,
           pId,
           pName,
           pliId,
           pliName;
    Decimal aRate;
    
    public JoinedAssignmentLineItem( SFDC_Assignment__c a, Project_Line_Item__c pli ) {
      aId = a.Id;
      aName = a.Name;
      aRate = a.Client_Rate__c;
      pId = a.Projects__r.Id;
      pName = a.Projects__r.Name;
      pliId = pli.Id;
      pliName = pli.Name;
    }
  }
  
  @RemoteAction
  public static String createTimecard( ID aId, ID pliId, date ddate, Decimal hours, Boolean billable, String description ) {
    SFDC_Timecard__c timecard = new SFDC_Timecard__c(
      Assignment__c = aId,
      Project_Line_Item__c = pliId,
      Date__c = ddate,
      Hours__c = hours,
      Type__c = billable ? 'Billable' : 'Non-Billable',
      Description_of_Work__c = description
    );
    
    try {
      insert timecard;
    } catch(DmlException dmle) {
      System.debug('Zoinks! Something went wrong... ' + dmle.getMessage());
    }
    
    return timecard.Id;
  }
  
  @RemoteAction
  public static Decimal updateTimecard( ID tId, Decimal newHours, Boolean billable, String description ) {
    SFDC_Timecard__c timecard = [SELECT Id, Hours__c FROM SFDC_Timecard__c WHERE Id =: tId];
    timecard.Hours__c = newHours;
    timecard.Type__c = billable ? 'Billable' : 'Non-Billable';
    timecard.Description_of_Work__c = description;
    try {
      update timecard;
    } catch(DmlException dmle) {
      System.debug('Jinkies! There was an issue: ' + dmle.getMessage());
    }
    
    return timecard.Hours__c;
  }
  
  @RemoteAction
  public static SFDC_Timecard__c[] getTimecards( ID resourceID, date startDate, date endDate ) {
    String startStr = startDate.year() + '-'
                    + (startDate.month() < 10 ? '0' + startDate.month() : '' + startDate.month()) + '-'
                    + (startDate.day() < 10 ? '0' + startDate.day() : '' + startDate.day()),
           endStr = endDate.year() + '-'
                  + (endDate.month() < 10 ? '0' + endDate.month() : '' + endDate.month()) + '-'
                  + (endDate.day() < 10 ? '0' + endDate.day() : '' + endDate.day());
    
    return Database.query(
      'SELECT Id, Project_Line_Item__c, Assignment__c, Date__c, Hours__c, Type__c, Description_of_Work__c '
    + 'FROM SFDC_Timecard__c '
    + 'WHERE Assignment__r.Resource__c = \'' + resourceID + '\''
    + 'AND (Date__c > ' + startStr + ' OR Date__c = ' + startStr + ') '
    + 'AND (Date__c < ' + endStr + ' OR Date__c = ' + endStr + ') '
    );
  }
}