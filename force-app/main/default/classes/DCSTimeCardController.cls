public without sharing class DCSTimeCardController {
    public class TeamTree{
        @AuraEnabled public list<TeamLevel> TeamTreeItems{get;set;}
        @AuraEnabled public boolean delegatePermission{get;set;}
        public TeamTree(){
            this.TeamTreeItems=new list<TeamLevel>();
        }
    }
    
    public class TeamLevel{
        @AuraEnabled public string Name {get;set;}
        @AuraEnabled public string treeName {get;set;}
        @AuraEnabled public Id resourceId {get;set;}
        @AuraEnabled public boolean isMe {get;set;}
        @AuraEnabled public list<ProjectLevel> Projects {get;set;}
        @AuraEnabled public list<string> ProjectSections {get;set;}
        
        public TeamLevel(contact resource){
            this.resourceID=resource.Id;
            this.Name = resource.FirstName + ' ' + resource.LastName;
            this.treeName=resourceID;
            this.isMe=false;
            this.Projects = new list<ProjectLevel>();
            this.ProjectSections = new list<string>();
        }
    }
    public class ProjectLevel{
        @AuraEnabled public string Name {get;set;}
        @AuraEnabled public string treeName {get;set;}
        @AuraEnabled public string projectId {get;set;}
        @AuraEnabled public Decimal HoursRemaining {get;set;}
        @AuraEnabled public string ProjStatus {get;set;}        
        @AuraEnabled public list<LineLevel> ProjectLines{get;set;}
        @AuraEnabled public list<LineLevel> AssignmentLines{get;set;}
        @AuraEnabled public integer AssignmentCount{get;set;}
        @AuraEnabled public boolean hasRecent{get;set;}
        @AuraEnabled public string Status{get;set;}
        
        public ProjectLevel(){
            
            this.ProjectLines = new list<LineLevel>();
            this.AssignmentLines = new list<LineLevel>();
            this.hasRecent=false;
        }
        public void setTreeName(string treeName){
            this.treeName = treeName;
        }
    }
    public class LineLevel{
        @AuraEnabled public string Name {get;set;}
        @AuraEnabled public Id Id {get;set;}
        @AuraEnabled public Decimal  BillableHoursRemaining {get;set;}
        @AuraEnabled public boolean Recent{get;set;}
        @AuraEnabled public string Status{get;set;}
        @AuraEnabled public boolean isMe{get;set;}
        @AuraEnabled public Id iAm{get;set;}
        @AuraEnabled public decimal HoursWorked{get;set;} 
        @AuraEnabled public decimal HoursTotal{get;set;} 
        @AuraEnabled public integer HoursPct{get;set;} 
        @AuraEnabled public string ColorText{get;set;}
        @AuraEnabled public Id FeatureId {get;set;}
        @AuraEnabled public list<FeatureLineLevel> FeatureLines{get;set;} 
        public LineLevel(){
            this.Recent=false;
            this.isMe=true;
        }
    }
    public class FeatureLineLevel{
        @AuraEnabled public string Description {get;set;}
        @AuraEnabled public string FullText {get;set;}
        public FeatureLineLevel(Project_Estimate_Feature_Line_Item__c fl){
            this.Description = fl.Description__c;
            this.FullText = fl.Name + ': '+fl.Description__c;
        }
    }
    public class TimeForDay {
        @AuraEnabled public Date dt {get;set;}
        @AuraEnabled public list<SFDC_TimeCard__c> entries{get;set;}
        @AuraEnabled public list<SFDC_TimeCard__c> delegatedEntries{get;set;}
        @AuraEnabled public decimal total {get;set;}
        @AuraEnabled public string status {get;set;}
        
        public TimeForDay(date dt, list<SFDC_TimeCard__c> entryList, set<Id> resourcesAsMe){
            this.dt = dt;
            this.entries = new list<SFDC_timecard__c>();
            this.delegatedEntries = new list<SFDC_timecard__c>();
            //handle my timecard & added for me, vs timecards added for others
            if (entryList!=null){
                for (SFDC_TimeCard__c e:entryList){
                    if (e.resource_delegate__c!=null && !resourcesAsMe.contains(e.resource_delegate__c)){
                        this.delegatedEntries.add(e);
                    } else {
                        this.entries.add(e);
                    }
                }
            }
            //this.entries=(entryList==null)?new list<SFDC_timecard__c>():entryList;
            this.total = 0;
            for (SFDC_TimeCard__c e:this.entries){
                this.total+=(e.hours__c!=null)?e.hours__c:0;
            }
            DateTime thisDay = (DateTime) this.dt;
            TimeZone tz = UserInfo.getTimeZone();
            integer tzoff = -1 * (tz.getOffset(thisDay)/3600000);
            //system.debug(tzoff);
            thisDay = thisDay.addHours(tzoff);
            String dayOfWeek = thisDay.format('E');
            
            //system.debug(dayOfWeek + ' ' + this.dt + ' ' + thisDay);
            if (dayOfWeek!='Sat' && dayOfWeek!='Sun'){
                if (this.total>=8){
                    this.status='Complete';
                } else if (this.total>0){
                    this.status='Partial';
                } else {
                    this.status='Empty';
                }
            }
            
        }
    }

    public class Timesheet {
        @AuraEnabled ID recordId {get;set;}
        @AuraEnabled Date startDate {get;set;}
        @AuraEnabled Date endDate {get;set;}
        @AuraEnabled String status {get;set;}

        public Timesheet(Timesheet__c record) {
            this.recordId = record.Id;
            this.startDate = record.Start_Date__c;
            this.endDate = record.End_Date__c;
        }
    }
    
    public class BillingPeriod {
        @AuraEnabled public List<TimeForDay> TimeCardDays {get;set;}
        @AuraEnabled public decimal total {get;set;}
        @AuraEnabled public string status {get;set;}
        @AuraEnabled public string format {get;set;}
        @AuraEnabled public boolean hasDelegated {get;set;}
        @AuraEnabled public List<Timesheet__c> Timesheets {get;set;}

        public BillingPeriod(){
            TimeCardDays = new List<TimeForDay>();
            Timesheets = new List<Timesheet__c>();
        }

        public void calcTotal(){
            integer full = (this.format=='Week')?40:80;
            this.total = 0;
            for(TimeForDay tfd:TimeCardDays){
                this.total+=tfd.total;
            }   
            if (this.total>=full){
                this.status='Complete';
            } else if (this.total>0){
                this.status='Partial';
            } else {
                this.status='Empty';
            }
        }
    }
    
    public class delegateInfo {
        @auraEnabled list<option> options{get;set;}
        @auraenabled Id myResource {get;set;}
        @auraEnabled boolean delegatePermission{get;set;}
        public delegateInfo(){
            options = new list<option>();
        }
    }

    public class option{
        @auraEnabled string value{get;set;}
        @auraEnabled string label{get;set;}
        public option(string value, string label){
            this.value=value;
            this.label=label;
        }
    }

    public class userData {
        @auraEnabled contact res {get;set;}
        @AuraEnabled list<aggregateresult> recents{get;set;}
    }

    @AuraEnabled(cacheable=true) 
    public static string getResourceFromUser (Id userId){
        userData ud = new userData();
        list<contact> resources = [select Id, Name, Resource_User_Record__c from Contact where Resource_User_Record__c=:userId ];
        if (!resources.isEmpty()){
            ud.res = resources[0];


            list<aggregateresult> recents = [select Project_Line_Item__c, Project_Line_Item__r.name, assignment__c, project_line_Item__r.project__c 
                                            from sfdc_timecard__c 
                                            where Assignment__r.Resource__c =:ud.res.Id
                                                and date__c >=: date.today()-90 
                                                //and Project_Line_Item__r.project__r.recordtype.developername!='Managed_Services' 
                                               and Project_Line_Item__r.Inactive__c = false
                                             group by Project_Line_Item__c, Project_Line_Item__r.name, project_line_Item__r.project__c, assignment__c];
            ud.recents=recents;
        }
        return JSON.serialize(ud);
    }
    @AuraEnabled
    public static date StartOfPeriod (integer rel){
        Date monday = Date.newInstance(1900, 1, 1);
        date dt = date.today();
        date startOfYear = date.newInstance(dt.year(), 1, 1);
        integer firstMondayOffset = -1*(Math.mod(monday.daysBetween(startOfYear), 7));
        date firstMondayThisYear = startOfYear.addDays(firstMondayOffset);
        firstMondayThisYear = (firstMondayThisYear.year()!=dt.year())?firstMondayThisYear.addDays(7):firstMondayThisYear;
        date startDate = firstMondayThisYear.addDays((firstMondayThisYear.daysbetween(dt)/14)*14);
        startDate = startDate.addDays((rel*14)-7);
        return startDate;
    }
    
    @AuraEnabled
    public static TeamTree getTeamProjectTree (contact resource){
        TeamTree tt = new TeamTree();
        tt.delegatePermission = FeatureManagement.checkPermission('TimeCardDelegate');
        
        map<Id,TeamLevel> tlmap = new map<Id,TeamLevel>();
        
        map<Id, list<contact>> resources = getResources(resource);
        set<Id>teamResourceIds = new set<Id>();
        Id myResourceId;
        boolean pastFirst=false;
        if (resources.size()>0){
            for (contact c:resources.values()[0]){
                if (tt.delegatePermission==true || pastfirst==false){
                    teamResourceIds.add(c.Id);
                    tlmap.put(c.Id, new TeamLevel(c));
                    pastFirst=true;
                }
            }
            myResourceId = resources.values()[0][0].Id;
            tlmap.get(myResourceId).isMe=true;
            
            map<Id, set<Id>> recentPLIByTeamMember = new map<Id, set<Id>>();
            //get active projects only for recents by team member.
            
            list<aggregateresult> recents = [select Project_Line_Item__c, assignment__r.resource__c res 
                                            from sfdc_timecard__c 
                                            where Assignment__r.Resource__c in:teamResourceIds 
                                                and date__c >=: date.today()-90 
                                                and Project_Line_Item__r.project__r.recordtype.developername!='Managed_Services' 
                                               and Project_Line_Item__r.Inactive__c = false
                                             group by assignment__r.resource__c,Project_Line_Item__c];
            if (recents.size()>0){
                for (aggregateresult agg:recents){
                    set<Id>recentPLI;
                    if (!recentPLIByTeamMember.containskey((Id)agg.get('res'))){
                        recentPLI=new set<Id>();
                        recentPLIByTeamMember.put((Id)agg.get('res'),recentPLI);
                    } else {
                        recentPLI = recentPLIByTeamMember.get((Id)agg.get('res'));
                    }
                    recentPLI.add((Id)agg.get('Project_Line_Item__c'));
                }
            }
            
            //Get all the active assignments by the contacts ID
            map<Id, SFDC_Assignment__c> assignments = new map<Id, SFDC_Assignment__c>([select id, name, Projects__c, Projects__r.Name, End_date__c, resource__c, Number_Of_Hours__c, Hours_Worked_On_Assignment__c  from SFDC_Assignment__c where resource__c in:teamResourceIds and (End_date__c=null or End_date__c>:date.today()-14) AND Inactive__c = false ]); 
            
            map<Id, set<Id>> projectsByTeamMember = new map<Id, set<Id>>();
            set<Id> allProjects = new set<Id>();
            for (SFDC_Assignment__c a:assignments.values()){
                set<Id> projects;
                if (!projectsByTeamMember.containskey(a.Resource__c)){
                    projects = new set<Id>();
                    projectsByTeamMember.put(a.resource__c, projects);
                } else {
                    projects = projectsByTeamMember.get(a.Resource__c);
                }
                projects.add(a.Projects__c);
                allProjects.add(a.Projects__c);
            }
            //system.debug('Projects');
            //System.debug(projectsByTeamMember);
            
            list<SFDC_Projects__c> projectBase = [select Id, Name, Hours_Remaining__c, Project_Status__c, 
                                                    (select Id, Name, Est_Hours__c, Billable_Hours_Worked__c, Billable_Hours_Remaining__c,Feature__c from Project_Line_Items__r where Inactive__c = false order by name ),
                                                    (select Id, Name, End_Date__c, resource__c, Number_Of_Hours__c, Hours_Worked_On_Assignment__c  from Assignments__r where resource__c in:teamResourceIds AND Inactive__c = False order by name)
                                                  from SFDC_Projects__c  
                                                  where 
                                                    id in :allProjects 
                                                    and recordtype.developername != 'Managed_Services'
                                                  order by Name];
            system.debug('projectBase');
            system.debug(projectBase);
            map<Id, map<Id, ProjectLevel>> projectLevelsByTeamMember = new map<Id, map<Id, ProjectLevel>>();
            map<Id, list<string>> projectSectionsByTeamMember = new map<Id, list<string>>();
            map<Id, list<FeatureLineLevel>> featureLineLevelsByProjectLine = new map<Id, list<FeatureLineLevel>>();
            for (SFDC_Projects__c prj:projectBase){
                //create projects for each team member with an assignment.
                for (SFDC_Assignment__c ali:prj.Assignments__r){
                    map<Id, ProjectLevel> projectLevelsForResource;
                    if (!projectLevelsByTeamMember.containsKey(ali.resource__c)){
                        projectLevelsForResource = new map<Id, ProjectLevel>();
                        projectLevelsByTeamMember.put(ali.resource__c, projectLevelsForResource);
                    } else {
                        projectLevelsForResource = projectLevelsByTeamMember.get(ali.resource__c);
                    }
                    if (!projectLevelsForResource.containsKey(prj.Id)){
                        ProjectLevel plx = new ProjectLevel();				/// Creates new ProjectLevel
                        plx.Name = prj.Name;
                        plx.HoursRemaining = prj.Hours_Remaining__c;
                        plx.ProjStatus = prj.Project_Status__c;
                        plx.projectId = prj.Id;
                        plx.setTreeName(string.valueOf(ali.resource__c) + string.valueOf(prj.Id));
                        projectLevelsForResource.put(prj.Id, plx);
                        
                        
                        //for each project line item create a line level record
                        for (Project_Line_Item__c pli:prj.Project_Line_Items__r){
                            featureLineLevelsByProjectLine.put(pli.Feature__c,new list<FeatureLineLevel>());
                            LineLevel pllx = new LineLevel();						///Creates new Line Level
                            pllx.Id = pli.Id;
                            pllx.Name = pli.Name;
                            pllx.BillableHoursRemaining = pli.Billable_Hours_Remaining__c;
                            pllx.HoursWorked = pli.Billable_Hours_Worked__c != null ? pli.Billable_Hours_Worked__c : 0;
                            pllx.HoursTotal = pli.Est_Hours__c;
                            pllx.HoursPct = pllx.HoursTotal > 0 ? (integer)((pllx.HoursWorked / pllx.HoursTotal) * 100) : 0;
                            pllx.HoursPct = Math.min(pllx.HoursPct, 100);
                            pllx.ColorText = 'Green';
                            if (pllx.HoursPct >= 100){
                                pllx.ColorText = 'Red';
                            } else if (pllx.HoursPct >= 75){
                                pllx.ColorText = 'Yellow';
                            }

                            set<Id> recentPLI = recentPLIByTeamMember.get(ali.resource__c);
                            pllx.isMe = (ali.resource__c==myResourceId);
                            pllx.iAm = myResourceId;
                            if (recentPLI!=null && recentPLI.contains(pli.Id)){
                                pllx.Recent=true;
                                plx.hasRecent=true;
                            }
                            pllx.FeatureId = pli.Feature__c;
                            plx.ProjectLines.add(pllx);
                        }
                        
                        boolean isEnding=false;
                        for (SFDC_Assignment__c alix:prj.Assignments__r){
                            if (alix.resource__c == ali.resource__c){
                                LineLevel allx = new LineLevel();
                                allx.Id=alix.Id;
                                allx.Name=alix.Name;
                                if (alix.End_Date__c !=null && date.today().daysbetween(alix.End_Date__c)<5){
                                    system.debug('Ending Project ' + alix.Name);
                                    allx.Status='Ending';
                                }
                                allx.HoursWorked=(alix.Hours_Worked_On_Assignment__c!=null)?alix.Hours_Worked_On_Assignment__c:0;
                                allx.HoursTotal =alix.Number_Of_Hours__c ;
                                allx.HoursPct = (allx.HoursTotal>0)?(integer)((allx.HoursWorked/allx.HoursTotal)*100):0;
                                allx.HoursPct = Math.min(allx.HoursPct,100);
                                allx.ColorText='Green';
                                if (allx.HoursPct>=100){
                                    allx.ColorText='Red';
                                } else if (allx.HoursPct>=75){
                                    allx.ColorText='Yellow';
                                }
                                plx.AssignmentLines.add(allx);
                            }
                        }
                        plx.status = (isEnding)?'Ending':'';
                        plx.AssignmentCount = plx.AssignmentLines.size();
                        tlmap.get(ali.resource__c).Projects.add(plx);
                        tlmap.get(ali.Resource__c).ProjectSections.add(plx.treeName);
                    }
                }
            }
            for(Project_Estimate_Feature_Line_Item__c featureLine:[Select Name, Description__c, Feature__c From Project_Estimate_Feature_Line_Item__c where Feature__c IN:featureLineLevelsByProjectLine.keySet()]){
                featureLineLevelsByProjectLine.get(featureLine.Feature__c).add(new FeatureLineLevel(featureLine));
            }
            for (TeamLevel tl:tlmap.values()){
                for (ProjectLevel pl:tl.Projects){
                    for (LineLevel pli:pl.ProjectLines){
                        if(!featureLineLevelsByProjectLine.get(pli.FeatureId).isEmpty()){
                            pli.FeatureLines = featureLineLevelsByProjectLine.get(pli.FeatureId);
                        }
                    }
                }
            }
        }
        tt.TeamTreeItems=tlmap.values();
        return tt;
    }
    @AuraEnabled
    public static list<ProjectLevel> getProjectTree(contact resource){
        list<ProjectLevel> pl = new list<ProjectLevel>();
        map<Id, list<contact>> resources = getResources(resource);
        if (resources.size()==0){
            //no resource;
        } else {
            set<Id> recentPLI = new set<Id>();
            //Todo: get active projects only for recents.
            list<aggregateresult> recents = [select Project_Line_Item__c 
                                            from sfdc_timecard__c 
                                            where Assignment__r.Resource__c in:resources.keyset() 
                                                and Project_Line_Item__r.project__r.recordtype.developername!='Managed_Services' 
                                                and Project_Line_Item__r.Inactive__c = false
                                             and date__c >=: date.today()-90 
                                            group by Project_Line_Item__c];
            if (recents.size()>0){
                for (aggregateresult agg:recents){
                    recentPLI.add((Id)agg.get('Project_Line_Item__c'));
                }
            }
            
            //Get all the active assignments by the contacts ID
            map<Id, SFDC_Assignment__c> assignments = new map<Id, SFDC_Assignment__c>([select id, name, Projects__c, Projects__r.Name, End_date__c, Number_Of_Hours__c, Hours_Worked_On_Assignment__c  
                                                                                       from SFDC_Assignment__c 
                                                                                       where resource__c in:resources.keyset()
                                                                                       and (End_date__c=null or End_date__c>:date.today()-14) 
                                                                                       AND Inactive__c = false 
                                                                                       Order by Projects__r.Name]); 
            set<Id> projects = new set<Id>();
            for (SFDC_Assignment__c a:assignments.values()){
                projects.add(a.Projects__c);
            }
            system.debug('Projects');
            System.debug(Projects);
            
            list<SFDC_Projects__c> projectBase = [select Id, Name, Hours_Remaining__c, Project_Status__c, (select Id, Name, Billable_Hours_Remaining__c  from Project_Line_Items__r where Inactive__c = false order by name),
                                                  (select Id, Name, End_Date__c from Assignments__r where resource__c in:resources.keyset() AND Inactive__c = False )
                                                  from SFDC_Projects__c  
                                                  where id in:projects 
                                                    and recordtype.developername!='Managed_Services'
                                                  order by name];
            system.debug('projectBase');
            system.debug(projectBase);
            
            for (SFDC_Projects__c prj:projectBase){
                ProjectLevel plx = new ProjectLevel();				/// Creates new ProjectLevel
                plx.Name = prj.Name;
                plx.HoursRemaining = prj.Hours_Remaining__c;
                plx.ProjStatus = prj.Project_Status__c;
                
                //for each project line item create a line level record
                for (Project_Line_Item__c pli:prj.Project_Line_Items__r){
                    LineLevel pllx = new LineLevel();						///Creates new Line Level
                    pllx.Id=pli.Id;
                    pllx.Name=pli.Name;
                    pllx.BillableHoursRemaining = pli.Billable_Hours_Remaining__c;
                    if (recentPLI.contains(pli.Id)){
                        pllx.Recent=true;
                        plx.hasRecent=true;
                    }
                    plx.ProjectLines.add(pllx);
                }
                
                
                boolean isEnding=false;
                for (SFDC_Assignment__c ali:prj.Assignments__r){
                    LineLevel allx = new LineLevel();
                    allx.Id=ali.Id;
                    allx.Name=ali.Name;
                    if (ali.End_Date__c !=null && date.today().daysbetween(ali.End_Date__c)<5){
                        system.debug('Ending Project ' + ali.Name);
                        allx.Status='Ending';
                    }
                    plx.AssignmentLines.add(allx);
                }
                plx.status = (isEnding)?'Ending':'';
                plx.AssignmentCount = plx.AssignmentLines.size();
                pl.add(plx);
            }
        }
        
        
        System.debug('PL');
        System.debug(pl);
        
        return pl;
    }
    
    //list of contacts contains the resource contacts for an account with the focused individual as the first item
    public static map<Id, list<contact>> getResources(contact resource){
        map<Id, list<contact>> res = new map<Id, list<contact>>();
        list<Contact> rl = new list<contact>();
        contact focus;    
        //find and add focus user.
        if (resource!=null){
            rl.add(resource);
            res.put(resource.Id, rl);
            focus=resource;
        } else {
            ID currentUserId = UserInfo.getUserId();//'005VF00000LAiYfYAL';
            User myself = [select firstname, lastname from user where Id = :currentUserId];
            list<Contact> cMyself = [select id, firstname, lastname, accountId from contact where firstname=:myself.firstname and lastname=:myself.LastName and recordtype.developername='Resource'];
            if (!cMyself.isEmpty()){
                rl.add(cMyself[0]);
                res.put(cMyself[0].Id, rl);
                focus=cMyself[0];
            }
        }
        //fill out team.
        if (focus!=null && focus.accountId!=null){
            list<contact> team = [select id, firstName, lastName, accountId from contact where accountID=:focus.accountId and id !=: focus.Id and recordtype.developername='Resource'];
            for (contact t:team){
                rl.add(t);
            }
        }
        return res;
    }
    
  
    @AuraEnabled
    public static BillingPeriod getTimecards(integer relTimePeriod, contact resource, string format){
        BillingPeriod bp = new BillingPeriod();
        bp.format=format;
        integer relativePeriod = (relTimePeriod!=null)?Integer.valueOf(relTimePeriod):-1;
        date periodStart; 
        date periodEnd;
        integer periodLength;
        if (format=='Billing Period') {
            periodStart = StartOfPeriod(relativePeriod);
            periodLength=14;
        } else {
            periodLength=7;
            periodStart = date.today().toStartOfWeek().addDays(relativePeriod*periodLength);
        }
        periodEnd = periodStart.addDays(periodLength);
        
        
        list<SFDC_Timecard__c> timeCards = new list<SFDC_Timecard__c>();
        
        map<Id, list<contact>> resources = getResources(resource);
        if (resources.size()==0){
            //no resource;
        } else {
            timeCards = [select id, Date__c, Hours__c, Project_Line_Item__r.Name, Assignment__r.name, Assignment__r.resource__c,
                         Description_of_Work__c, Resource_Delegate__c, Resource_Id__c  
                         from  SFDC_Timecard__c 
                         where (Assignment__r.resource__c in:resources.keyset() or resource_delegate__c in:resources.keyset()) 
                         and date__c>=:periodStart and date__c<:periodEnd];
            system.debug(periodStart + ' - ' + periodEnd);
        }
        //system.debug(timecards);
        set<Id>resourceIds = new set<Id>();
        map<date, list<SFDC_Timecard__c>> sparseFill = new map<date, list<SFDC_Timecard__c>>();
        for (SFDC_Timecard__c t:timeCards){
            list<SFDC_Timecard__c> tc;
            if (!sparseFill.containskey(t.date__c)){
                tc = new list<SFDC_Timecard__c>();
                sparseFill.put(t.date__c, tc);
            } else {
                tc = sparseFill.get(t.date__c);
            }
            tc.add(t);
            resourceIds.add(t.Resource_Id__c);
        }
        for (integer i=0;i<periodLength;i++){
            date onDate = periodStart.addDays(i);
            
            list<SFDC_Timecard__c> tc = (sparseFill.containskey(onDate))?sparseFill.get(OnDate):null;
            system.debug('add Day');
            system.debug(OnDate);
            system.debug(tc);
            bp.TimeCardDays.add(new timeForDay(OnDate, tc, resources.keyset()));
            
        }
        bp.calcTotal();
        bp.hasDelegated = (resourceIds.size()>1);

        if(resources.values().size() > 0 && resources.values()[0].size() > 0) {
            resource = resources.values()[0][0];

            periodEnd = periodEnd.addDays(-1);
            Date startOfPeriodWeek = periodEnd.toStartOfWeek();
            Date lastWorkDayOfWeek = startOfPeriodWeek.addDays(5);

            for(Timesheet__c record : [select Start_Date__c, End_Date__c from Timesheet__c where Resource__c = :resource.Id and Start_Date__c <= :periodEnd and End_Date__c >= :periodStart and Status__c = 'Not Submitted']) {
                if(Date.today() <= startOfPeriodWeek) continue;
                bp.Timesheets.add(record);
            }
        }

        return bp;
    }
    
    @AuraEnabled
    public static list<string> getTimecardTypes(){
        list<string> out = new list<String>();
        out.add('');
        Schema.DescribeFieldResult fieldResult = SFDC_TimeCard__c.Type__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry f : ple){
            out.add(f.getLabel());
        }
        return out;
    }
    
    @AuraEnabled
    public static delegateInfo getDelegateOptions(){
        delegateInfo delegateOptions = new delegateInfo();
        delegateOptions.delegatePermission = FeatureManagement.checkPermission('TimeCardDelegate');
        if (delegateOptions.delegatePermission){
            
            User myself = [select id, firstname, lastname from user where id=:userinfo.getUserId()];
            list<Contact> cMyself = [select id, firstname, lastname, accountId from contact where firstname=:myself.firstname and lastname=:myself.LastName and recordtype.developername='Resource'];
            if (cMyself[0]!=null && cMyself[0].accountId!=null){

                list<contact> resources = [select id, name from contact where accountID=:cMyself[0].accountId and recordtype.developername='Resource'];
                for (contact c:resources){
                    delegateOptions.options.add(new option(c.Id, c.Name));
                }
            }
            map<Id, list<contact>> res = getResources(null);
            system.debug(res);
            if (!res.isEmpty()){
                delegateOptions.myResource=res.values()[0][0].Id;
            }
        }
        return delegateOptions;
    }

    @AuraEnabled
    public static void submitTimesheet(String recordId) {
        List<Contact> resources = [select Id from Contact where Resource_User_Record__c = :UserInfo.getUserId()];
        if(resources.isEmpty()) throw new AuraHelper.AuraException('Can not find a Resource.');

        Contact resource = resources[0];
        List<Timesheet__c> timesheets = [select Status__c, Start_Date__c, End_Date__c from Timesheet__c where Id = :recordId and Resource__c = :resource.Id and Status__c = 'Not Submitted'];
        if(timesheets.isEmpty()) throw new AuraHelper.AuraException('Can not find a Timesheet.');
  
        Approval.ProcessSubmitRequest request = new Approval.ProcessSubmitRequest();
        request.setComments('Submitting Timesheet for approval.');
        request.setObjectId(timesheets[0].Id);
        request.setSubmitterId(UserInfo.getUserId()); 
        
        try{
            Approval.process(request);
        }catch(Exception ex) {
            throw new AuraHelper.AuraException(ex.getMessage());
        }
    }

    //LWC timecard methods
    public class timeEntry{
        @auraEnabled public SFDC_Timecard__c timecard {get;set;}
        @auraEnabled public string tcid {get;set;}
        @auraEnabled public string hours {get;set;}
        @auraEnabled public string workDate {get;set;} 
        @auraEnabled public string projectId {get;set;} 
        @auraEnabled public string lineItemId {get;set;} 
        @auraEnabled public string assignmentId {get;set;} 
        @auraEnabled public string projectName {get;set;}
        @auraEnabled public string description {get;set;}
        @auraEnabled public boolean diff {get;set;}

        public timeEntry(){}
        public timeEntry(SFDC_timecard__c tc){
            this.timecard = tc;
            this.tcid = tc.Id;
            this.hours = string.valueof(tc.Hours__c);
            this.workDate = tc.date__c.toString().split(' ')[0];
            this.projectId = tc.project_line_item__r.project__c;
            this.lineItemId = tc.project_line_item__c;
            this.assignmentId = tc.Assignment__c;
            this.projectName = tc.project_line_item__r.name;
            this.description = tc.description_of_work__c;
            this.diff=false;
        }
    }
    @AuraEnabled
    public static string getWeek(date focusDate){
        date weekStart = focusDate.toStartOfWeek().addDays(-1);
        date weekEnd = weekStart.addDays(8);
        list<sfdc_timecard__c> thisWeek = [select id, Hours__c, Date__c, Assignment__c, project_Line_Item__c, project_Line_Item__r.project__c, description_of_work__c, project_line_item__r.name from sfdc_timecard__c where assignment__r.resource__r.Resource_User_Record__c=:Userinfo.getUserId() and Date__c>=:weekStart and Date__c<:weekEnd];
        system.debug(string.format('{0} - {1}',new list<object>{weekStart,weekEnd} ));
        //system.debug(thisWeek);
        list<timeEntry> week = new list<timeEntry>();
        for (sfdc_timecard__c tc: thisWeek){
            timeEntry e = new timeEntry(tc);
            week.add(e);
        }
        return JSON.serialize(week);
    }
    @AuraEnabled
    public static string submitTimeEntry(string timeEntryJSON){
        timeEntry te = (timeEntry)JSON.deserialize(timeEntryJSON, timeEntry.class);
        SFDC_Timecard__c timecard = new SFDC_Timecard__c();
        if (te.tcId!='new'){
            timecard = new SFDC_Timecard__c(Id=te.tcid);
        }
        timecard.Hours__c = decimal.valueOf(te.hours);
        timecard.Date__c = Date.valueOf(te.workDate);
        timecard.Assignment__c = te.assignmentId;
        timecard.Project_Line_Item__c = te.lineItemId;
        timecard.Description_of_Work__c = te.description;

        upsert timecard;

        te.tcId = timecard.Id;
        te.timecard = timecard;
        te.diff=false;
        return JSON.serialize(te);
    }
}