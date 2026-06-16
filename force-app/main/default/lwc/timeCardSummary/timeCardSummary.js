import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';


import getResourceFromUser from "@salesforce/apex/DCSTimeCardController.getResourceFromUser";
import submitTimeEntry from "@salesforce/apex/DCSTimeCardController.submitTimeEntry";
import getWeek from "@salesforce/apex/DCSTimeCardController.getWeek";
import UserId from "@salesforce/user/Id";
import PROJECTNAME from '@salesforce/schema/SFDC_Assignment__c.Projects__r.Name';
import PROJECTID from '@salesforce/schema/SFDC_Assignment__c.Projects__c';

const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

export default class TimeCardSummary extends LightningElement {

    filteredTimeList=[]; 
    @track timeEntry={}; //these are form fields, and associated sfdcTimecard.

    @api projectId;
    @api assignmentId;
    assignmentData;
    pliSelection;
    timerId;
    resourceUserId = UserId;
    currentResourceId;

    showPanel = false;
    showPanelSpinner = false;
    selectedDay;
    weekStartDate; //Sunday

    
    get searchAvailable(){
        //console.log("search available",(this.currentResourceId!=undefined));
        return (this.currentResourceId!=undefined);
    }
    assignmentFilter = {}

    assignmentDisplay = {
        primaryField: "Projects__r.Name"
    }

    recentColumns = [
        { label: 'Name', fieldName: 'name' },
        {
            type: 'button-icon',
            fixedWidth:70,
            typeAttributes: {
                iconName: 'utility:choice',
                name: 'select',
                variant: 'brand'
            }
        }
    ];

    recentData = [];
    

    //Week start date -> dayIndex -> timeEntries
    calendar={};
    todaysEntries;

    dayIndex=0;
    gtot=0;
    dtots=[0,0,0,0,0,0,0];

    daysWithUnsaved=[];
    
    get recentClass(){
        return (this.recentData && this.recentData.length>10)?"recent-force-scroll":"";
    }

    get hStyle(){
        let gt = Math.floor((this.gtot) / 5);
        gt = (gt>8)?8:gt;
        return 'tot-' + gt;
    }

    get selectedDayName() {
        return dayNames[this.dayIndex] + " " + this.dateExt(this.dayIndex) + " - " + this.dtots[this.dayIndex] + " hr" + ((this.dtots[this.dayIndex]!=1)?"s":"");
    }

    get weekStart(){
        return (this.weekStartDate)?this.weekStartDate.toDateString():"";
    }

    get showAddTime(){
        return true;
    }

    get isNotNew(){
        return this.timeEntry.tcid!="new";
    }

    get tabSu(){ return "Su"};// + this.dateExt(0);}
    get tabMo(){ return "Mo"};// + this.dateExt(1);}
    get tabTu(){ return "Tu"};// + this.dateExt(2);}
    get tabWe(){ return "We"};// + this.dateExt(3);}
    get tabTh(){ return "Th"};// + this.dateExt(4);}
    get tabFr(){ return "Fr"};// + this.dateExt(5);}
    get tabSa(){ return "Sa"};// + this.dateExt(6);}

    get isFirstSu(){return (this.addDays(this.weekStartDate, 0).getDate()==1);}
    get isFirstMo(){return (this.addDays(this.weekStartDate, 1).getDate()==1);}
    get isFirstTu(){return (this.addDays(this.weekStartDate, 2).getDate()==1);}
    get isFirstWe(){return (this.addDays(this.weekStartDate, 3).getDate()==1);}
    get isFirstTh(){return (this.addDays(this.weekStartDate, 4).getDate()==1);}
    get isFirstFr(){return (this.addDays(this.weekStartDate, 5).getDate()==1);}
    get isFirstSa(){return (this.addDays(this.weekStartDate, 6).getDate()==1);}

    dateExt(ofDay){
        let day = this.addDays(this.weekStartDate, ofDay).getDate();
        let ending = "th";
        switch (true){
            case [1,21,31].includes(day):
                ending = "st";
                break;
            case [2,22].includes(day):
                ending = "nd";
                break;
            case [3,23].includes(day):
                ending = "rd";
                break;
        }
        return day+"<sup>"+ending+"</sup>";
    }

    connectedCallback(){
        this.handleHome(null);
        //this.selectedDay = new Date();
        //this.queryWeek();

    }

    queryWeek(){
        this.weekStartDate = new Date();
        let ofDay = -1 * this.selectedDay.getDay();
        this.weekStartDate = this.addDays(this.selectedDay, ofDay);
        console.log("Set initial date",this.selectedDay.toISOString().split('T')[0], ofDay, this.weekStartDate);

        getWeek({focusDate:this.selectedDay}).then(result=>{
            console.log("get week", result);
            const incoming = JSON.parse(result);
            incoming.forEach(item=>{
                this.addTimeEntryToCalendar(item);
            });
            
        }).finally(()=>{

            this.todaysEntries = this.ensureDateInCalendar(this.selectedDay.toISOString().split('T')[0]);
            this.updateTabs();
            setTimeout(() => {
                const day = this.selectedDay.getDay();
                let tabs = this.template.querySelectorAll('li.day-tab');
                tabs[day].querySelector('a').click();
            }, 20);
        });
    }

    addDays(fromDate, numberOfDays){
        return new Date(fromDate.getTime() + (numberOfDays * 24 * 60 * 60 * 1000));
    }

    handleHome(event){
        this.selectedDay = new Date();
        this.queryWeek();
    }
    handleLastWeek(event){
        //console.log('handle Last Week from ' + this.selectedDay);
        this.selectedDay = this.addDays(this.selectedDay, -7);
        this.queryWeek();
    }
    handleNextWeek(event){
        //console.log('handle Next Week from ' + this.selectedDay);
        this.selectedDay = this.addDays(this.selectedDay, 7);
        this.queryWeek();
    }

    handleTabActive(event){
        console.log('HandleTabActive');
        let tabs = this.template.querySelector('[data-id="dayTabs"]');
        tabs.querySelectorAll(":scope li.slds-is-active").forEach((tab) => {
            tab.classList.remove("slds-is-active");
        });
        console.log('all tabs deactivated');
        event.target.parentNode.classList.add("slds-is-active");
        this.dayIndex=Number(event.target.id.substring(4,5));
        console.log(this.dayIndex);

        const targetDate = this.addDays(this.weekStartDate, this.dayIndex);
        console.log("from " + this.selectedDay + "to " + targetDate);
        this.selectedDay = targetDate;
        this.todaysEntries = this.ensureDateInCalendar(this.selectedDay.toISOString().split('T')[0]);
        console.log("finish active tab");
    }

    updateTabs(){
        let tabs = this.template.querySelectorAll('li.day-tab');
        this.gtot=0;
        this.dtots=[0,0,0,0,0,0,0];
        let weekData;
        let weekStartKey = this.weekStartDate.toISOString().split('T')[0];
        //console.log("updateTabs", weekStartKey, this.calendar);
        if (Object.hasOwn(this.calendar, weekStartKey)){
            weekData = this.calendar[weekStartKey];
        }
        
        for(var i=0;i<7;i++){
            if(tabs[i]){
                const classes = Array.from(tabs[i].classList);
                let diffToday=false;
                for (const className of classes) {
                    if (className.startsWith('tot-')) {
                        tabs[i].classList.remove(className);
                    }
                }
                let total=0;
                //console.log("has data today", i, (weekData && weekData[i]));
                if (weekData && weekData[i]){
                    weekData[i].forEach(entry=>{
                       //console.log(entry);
                        if (entry.timecard.Hours__c){
                            total+=Number(entry.timecard.Hours__c);
                        }
                        if (entry.diff==true){
                            diffToday=true;
                        }
                    });
                }
                //console.log(i,diffToday);
                this.daysWithUnsaved[i] = diffToday;
                if (this.daysWithUnsaved[i]==true){
                    tabs[i].classList.add('unsaved');
                } else {
                    tabs[i].classList.remove('unsaved');
                }
                this.gtot+=total;
                this.dtots[i]=total;
                
                total = (total>8)?8:total;
                if (total>0){
                    tabs[i].classList.add('tot-' + Math.floor(total));
                }
            }
        }
    }

    handleAddTime(event){
        //console.log("Add time");
        this.panelType = 'newEntry';
        let timecard = {Hours__c:0, Date__c:this.selectedDay.toISOString().split('T')[0]};
        //console.log(timecard);
        this.timeEntry = this.wrapTimecard(timecard);
        this.timeEntry.diff=true;
        //console.log(this.timeEntry);
        this.addTimeEntryToCalendar(this.timeEntry);
        this.template.querySelector('lightning-tabset[data-section="project"]').activeTabValue="recent";
            
        this.openFormPanel();
    }
    wrapTimecard(sfTimecard){
        const entry = {timecard:sfTimecard};
        entry.tcid = (sfTimecard&&sfTimecard.id)?sfTimecard.tcid:"new";
        entry.hours = sfTimecard.Hours__c;
        entry.workDate=new Date(sfTimecard.Date__c).toISOString().split('T')[0];
        return entry;
    }
    //calendar management
    ensureDateInCalendar(aDate){
        let fDate = new Date(aDate + 'T00:00:01');
        let ofDay = fDate.getDay();//+1; //Day objects point to 00:00:00 which registers as yesterday in getDay    
        let weekStart = new Date();
        weekStart = this.addDays(fDate, -1 * ofDay);
        let weekStartKey = weekStart.toISOString().split('T')[0];
        console.log("Ensure", aDate, fDate, ofDay, weekStart, weekStartKey, fDate.getTime());
        if (!Object.hasOwn(this.calendar, weekStartKey)){
            this.calendar[weekStartKey] = [];
        }
        console.log("current weekLength", this.calendar[weekStartKey].length);
        //if (this.calendar[weekStartKey].length<=ofDay){
        if (this.calendar[weekStartKey][ofDay]==undefined){
            console.log('Adding');
            this.calendar[weekStartKey][ofDay] = []; 
        }      
        console.log("Ensure ", aDate, weekStartKey, ofDay);
        console.log("Calendar", this.calendar);
        return this.calendar[weekStartKey][ofDay];
    }
    addTimeEntryToCalendar(entry){
        console.log("add Calendar for:", entry.workDate);
        if (entry.workDate){
            const workdateEntries = this.ensureDateInCalendar(entry.workDate);
            console.log('workdateEntries', workdateEntries);
            if (!workdateEntries.find(item=>item.tcid===entry.tcid)){
                workdateEntries.push(entry);
            } else {
                console.log(entry.tcid, 'exists');
            }
        }
        console.log("Calendar", this.calendar);
    }

    //Form related
    @wire(getResourceFromUser, {userId: '$resourceUserId'})
    wiredResource({error,data}){
        let trd = new Array();
        if(data){
            const ud = JSON.parse(data);
            console.log(ud);
            if (ud.res==null){
                this.showToast('Error', 'Current user is not an Ascend Resource.', 'error');
            } else {
                this.currentResourceId = ud.res.Id;
                
                ud.recents.forEach(recent=>{
                    //console.log(recent);
                    trd.push({
                        assignmentId: recent.Assignment__c, 
                        lineItemId:recent.Project_Line_Item__c, 
                        projectId:recent.Project__c, 
                        name:recent.Name})
                });
                //console.log("getResourceFromUser",this.currentResourceId, data);
                this.assignmentFilter = {
                    criteria: [
                        {fieldPath: "Resource__c", operator:"eq", value:this.currentResourceId}
                    ]
                }
            }
        }
        trd.sort((a, b) => a.name.localeCompare(b.name));
        this.recentData = [... trd];
        console.log(this.recentData);
        if (error){
            console.log("getResourceFromUser error", error);
        }
    }


    @wire(getRecord, { recordId: '$assignmentId', fields: [PROJECTID, PROJECTNAME] })
    wiredProject({error,data}){
        if (data){
            this.assignmentData = data;
            //console.log("assignment data", this.assignmentData);
            this.projectId = this.assignmentData.fields.Projects__c.value;
            //console.log('got ProjectId',this.projectId);
        }
        if (error){
            console.log(error);
        }
    }

    @wire(getRelatedListRecords, {parentRecordId: '$projectId', relatedListId: 'Project_Line_Items__r', fields: ['Project_Line_Item__c.Name', 'Project_Line_Item__c.Id']})
    wiredProjectLines({error,data}){
        console.log('W2 wiredProjectLines');
        if (data){
            this.pliSelection = [];
            data.records.forEach(item => {
                var valueSelected=false;
                if (this.timeEntry.lineItemId){
                    valueSelected = (this.timeEntry.lineItemId==item.fields.Id.value);
                    if (valueSelected){
                        this.timeEntry.projectName = item.fields.Name.value;
                    }
                }
                let option = {value:item.fields.Id.value, label:item.fields.Name.value, selected:valueSelected};
                this.pliSelection.push(option);
            });
            if (this.pliSelection.length>0){
                this.pliSelection.unshift({value:null, label:"--Select--", selected:false});
            }
        }
        if (error){
            console.log('error', JSON.stringify(error));
        }
    }


    //used
    get hasLineItems() {
        return this.pliSelection && this.pliSelection.length>0;
    }
    get panelTitle() {
        return this.panelType === 'newEntry' ? 'Add Entry' : 'Update Entry';
    }


    handleChange(event) {
        console.log('Change event');
        console.log(JSON.stringify(event.target.dataset), event.target.value);
        const field = event.target.dataset.field;
        const picker = this.refs.assignmentPicker;
        picker.setCustomValidity('');   
        picker.reportValidity();

        let val = null;
        switch (field){
            case "assignmentId":
                console.log("assignmentId", JSON.stringify(event.detail) );
                val = event.detail.recordId;
                this.assignmentId = val;
                if (this.assignmentId==null){
                    this.pliSelection = null;
                    this.timeEntry["lineItemId"]=null;
                }
                break;
            case "lineItemId":
                val = event.target.value;
                const lineItem = this.pliSelection.find(item => item.value===val);
                this.timeEntry.projectName = (lineItem!=undefined)?lineItem.label:this.timeEntry.projectName;
                break;
            case "workDate":
                val = event.target.value.split('T')[0];
                break;
            default:
                val = event.target.value;
                break;
        }
        this.timeEntry[field] = val;
        this.timeEntry.diff=true;
        this.daysWithUnsaved[this.dayIndex]=true;
        this.updateTabs();
        
    }


    openFormPanel() {
        
        
        this.showPanel = true;
        //this.timeEntry
    }

    handleEntryClick(event){
        //console.log("handleEntryClick", event.detail, this.todaysEntries);
        const te = this.todaysEntries.find(item=>item.tcid===event.detail);
        this.timeEntry=te;
        this.projectId = te.projectId;
        this.template.querySelector('lightning-tabset[data-section="project"]').activeTabValue="search";
        this.panelType='update entry';
        this.openFormPanel();
    }

    closePanel() {
        this.showPanel = false;
        this.panelType = '';
        this.showPanelSpinner=false;
    }

    //convert to assignment Id
    handleRecentRowSelect(event) {
        //console.log("Row select", JSON.stringify(event.detail.row));
        if (event.detail.row){
            const row = event.detail.row;
            this.projectId = row.projectId;
            this.timeEntry.projectId = row.projectId;
            this.timeEntry.lineItemId = row.lineItemId;
            this.timeEntry.assignmentId = row.assignmentId;
            this.timeEntry.projectName = row.name;
            
            this.template.querySelector('lightning-tabset[data-section="project"]').activeTabValue="search";
            
        }
    }

    validateForm(){
        console.log('validate');
        const fields = this.template.querySelectorAll('.timeform');
        
        let isFormValid = true;
        fields.forEach(inputField => {
            if (!inputField.checkValidity()) {
                inputField.reportValidity(); // Highlights the specific error
                isFormValid = false;
            }
        });   
        const line = this.timeEntry["lineItemId"];
        console.log("line check", line);
        const picker = this.refs.assignmentPicker;
        if (!line || line=="--Select--"){
            isFormValid = false;
            this.template.querySelector('lightning-tabset[data-section="project"]').activeTabValue="search";
            picker.setCustomValidity('Select an assignment and Line Item.');
            console.log('here');
        }  else {
            picker.setCustomValidity('');      
        }
        picker.reportValidity();
            
        return isFormValid;    
    }

    handleSubmitTimeForm() {
        console.log('Form Data:', JSON.stringify(this.timeEntry));
        if (this.validateForm()){
            this.showPanelSpinner=true;
            submitTimeEntry({timeEntryJSON:JSON.stringify(this.timeEntry)}).then(result=>{
                try{
                    console.log('return:', result);
                    const res = JSON.parse(result);

                    const index = this.todaysEntries.findIndex(item=>item.tcid===this.timeEntry.tcid);
                    this.todaysEntries.splice(index,1);

                    //entry mgiht have a different date, so remove from today and repush.
                    res.diff=false;
                    this.addTimeEntryToCalendar(res);
                    this.updateTabs();
                    this.closePanel();

                    this.updateRecents();

                } catch (ex){
                    let messages=[];
                    ex.body.pageErrors.forEach(e=>{
                        messages.push(e.message);
                    })
                    console.log(messages);
                }
                
            }).error(err=>{
                console.log(err);
            }).finally(()=>{
                this.showPanelSpinner=false;
            })
        }
        
    }

    handleSaveAsNewEntry(event){
        console.log("Save as new entry");
        if (this.validateForm()){
            let clone = JSON.parse(JSON.stringify(this.timeEntry));

            clone.tcid="new";
            clone.timecard.Id = null;
            console.log(clone);

            //reset original
            this.timeEntry.hours = this.timeEntry.timecard.Hours__c;
            this.timeEntry.workDate = this.timeEntry.timecard.Date__c;
            this.timeEntry.description = this.timeEntry.timecard.Description_of_Work__c;
            this.timeEntry.assignmentId = this.timeEntry.timecard.Assignment__c;
            if (clone.lineItemId != this.timeEntry.timecard.Project_Line_Item__c){
                //will need to look up the projectName rom somewhere.
            }
            this.timeEntry.lineItemId = this.timeEntry.timecard.Project_Line_Item__c;
            this.timeEntry.diff=false;
            console.log(this.timeEntry);

            this.timeEntry = clone;
            console.log("Add to calendar");
            this.addTimeEntryToCalendar(this.timeEntry);
            console.log("Submit");
            this.handleSubmitTimeForm();
        }
    }

    updateRecents(){
        
        const formData = this.timeEntry;
        console.log('UpdateRecents', formData);
        if (!this.recentData.find(item=>item.lineItemId===formData.lineItemId)){
            console.log('entry not in recents, pushing.');
            const trd = this.recentData;
            trd.push({
                assignmentId: formData.assignmentId, 
                lineItemId:formData.lineItemId, 
                name:formData.projectName});
            trd.sort((a, b) => a.name.localeCompare(b.name));
            this.recentData = [... trd];
            console.log(this.recentData);
        }
    }

    get drawerClass() {
        return `drawer ${this.showPanel ? 'open' : ''}`;
    }

    showToast(title, message, variant) {
        const showToast = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        dispatchEvent(showToast);
    }
}