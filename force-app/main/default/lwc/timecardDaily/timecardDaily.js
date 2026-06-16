import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import getResourceFromUser from "@salesforce/apex/DCSTimeCardController.getResourceFromUser";
import UserId from "@salesforce/user/Id";
import PROJECTNAME from '@salesforce/schema/SFDC_Assignment__c.Projects__r.Name';
import PROJECTID from '@salesforce/schema/SFDC_Assignment__c.Projects__c';


export default class TimecardDaily extends LightningElement {
    timeEntry={};
    @api projectId;
    @api assignmentId;
    assignmentData;
    pliSelection;
    timerId;
    resourceUserId = UserId;
    currentResourceId;
    searchAvailable=false;

    showPanel = false;
    
    assignmentFilter = {
        criteria: [
            {fieldPath: "Resource__c", operator:"eq", value:'003VF000013u3ImYAI'}//this.currentResourceId}
        ]
    }
    assignmentDisplay = {
        primaryField: "Projects__r.Name"
    }

    recentColumns = [
        { label: 'Name', fieldName: 'name' },
        {
            type: 'button-icon',
            initialWidth:20,
            typeAttributes: {
                iconName: 'utility:choice',
                name: 'select',
                variant: 'brand'
            }
        }
    ];

    recentData = [
        { lineItemId:"a0KUv00000Er0wJMAR", projectId:"a0OUv000002GfUHMA0", name:"Company Internal - Internal Tasks"},
        { lineItemId:"a0KUv00000ErAytMAF", projectId:"a0OUv000002GfUHMA0", name:"Company Internal - FTO"},
    ];
    
    @wire(getResourceFromUser, {userId: '$resourceUserId'})
    wiredResource({error,data}){
        if(data){
            this.currentResourceId = data.Id;
            this.searchAvailable = true;
            console.log("getResourceFromUser",this.currentResourceId, data);
            
        }
        if (error){
            console.log("getResourceFromUser error", error);
        }
    }

    @wire(getRecord, { recordId: '$assignmentId', fields: [PROJECTID, PROJECTNAME] })
    wiredProject({error,data}){
        if (data){
            this.assignmentData = data;
            console.log("assignment data", this.assignmentData);
            this.projectId = this.assignmentData.fields.Projects__c.value;
            console.log('got ProjectId',this.projectId);
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

    get hasLineItems() {
        return this.pliSelection && this.pliSelection.length>0;
    }
    get panelTitle() {
        return this.panelType === 'newEntry' ? 'Add Entry' : 'Update Entry';
    }

    get panelData() {
        return this.timeEntry;
    }

    get entrySummary (){
        if (this.timeEntry===null){
            this.timeEntry = {};
        }
        let summary=[];
        summary.push((this.timeEntry.projectName)?this.timeEntry.projectName:'Project missing');
        summary.push((this.timeEntry.hours)?(this.timeEntry.hours + ' hours'):'Duration missing');
        summary.push((this.timeEntry.description)?(this.timeEntry.description):'Description missing');
        return summary.join(', ') + '.';
    }

    handleChange(event) {
        console.log('Change event');
        console.log(JSON.stringify(event.target.dataset), event.target.value);
        const field = event.target.dataset.field;
        
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
            default:
                val = event.target.value;
                break;
        }
        this.timeEntry[field] = val;
        
    }


    openFormPanel() {
        this.panelType = 'newEntry';
        this.showPanel = true;
    }

    closePanel() {
        this.showPanel = false;
        this.panelType = '';
    }

    //convert to assignment Id
    handleRowSelect(event) {
        console.log("Row select", JSON.stringify(event.detail.row));
        if (event.detail.row){
            const row = event.detail.row;
            this.projectId = row.projectId;
            this.timeEntry.projectId = row.projectId;
            this.timeEntry.lineItemId = row.lineItemId;
        }
    }

    handleSubmit() {
        console.log('Form Data:', JSON.stringify(this.timeEntry));
    }


    get drawerClass() {
        return `drawer ${this.showPanel ? 'open' : ''}`;
    }
    
}