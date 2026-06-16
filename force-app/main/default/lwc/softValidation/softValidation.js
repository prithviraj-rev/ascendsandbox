import {wire, api, LightningElement} from 'lwc';
import {getRecord} from 'lightning/uiRecordApi';
import getRulesQualifiedForEvaluation from '@salesforce/apex/SoftValidationController.getRulesQualifiedForEvaluation';
import evaluateRules from '@salesforce/apex/SoftValidationController.evaluateRules';

const MAX_PARALLEL_REQUESTS = 3; //number of "evaluate rules" requests that can be kicked off simultaneously
const BATCH_SIZE = 10; //number of rules that can be evaluated simultaneously per request

const MSG_TYPE_PARAMS = {
  'Error': {
    cssClasses: 'notify-alert-container',
    iconName: 'utility:error',
    iconAlternativeText: 'Error',
    iconTitle: 'Error',
    iconVariant: 'inverse',
    backgroundColor: '#ea001e'
  },
  'Warning': {
    cssClasses: 'notify-alert-container',
    iconName: 'utility:warning',
    iconAlternativeText: 'Warning',
    iconTitle: 'Warning',
    iconVariant: '',
    backgroundColor: '#fe9339'
  },
  'Success': {
    cssClasses: 'notify-alert-container',
    iconName: 'utility:success',
    iconAlternativeText: 'Success',
    iconTitle: 'Success',
    iconVariant: 'inverse',
    backgroundColor: '#2e844a'
  },
  'Info': {
    cssClasses: 'notify-alert-container',
    iconName: 'utility:info_alt',
    iconAlternativeText: 'Info',
    iconTitle: 'Info',
    iconVariant: 'inverse',
    backgroundColor: '#706e6b'
  }
};

export default class SoftValidation extends LightningElement {
  @api recordId;
  recordIdForWireAdapter; //this property is needed for delayed "activation" of the @wire(getRecord) adapter
  @api maxContainerHeight;
  @api maxMessages;
  
  /*
  * We don't want to bind the adapter to '$recordId' property, as it causes problems (page crashes) in the standard workPlanRelatedListView.js on a Work Order flexi page.
  * This issue is also related to the standard "Work Plans" LWC, which requires both: Work Plans and Work Steps related lists to be present on the master page layout.
  * When "Work Plans" LWC is put behind a tab, which isn't default, then all works good and flexi page does not crash even if this adapter is bind to '$recordId'.
  *
  * As a workaround, we bind the adapter to a different property - '$recordIdForWireAdapter', which is populated once the softValidation LWC
  * fully loads and fetches data from server (plus 2 secs on top of that), in other words this adapter becomes "active" with some DELAY after the page was loaded.
  * This delay lets standard "Work Plans" LWC to load successfully.
   */
  @wire(getRecord, { recordId: '$recordIdForWireAdapter', fields: ['Id'] })
  wiredRecord({ error, data }) {
    if (this.isIniting === false) {
      if (this.skipFirstWireGetRecordEvent === true) {
        //we don't want to refresh the contents once this.recordIdForWireAdapter gets populated, as it triggers this adapter.
        this.skipFirstWireGetRecordEvent = false;
      } else {
        this.reload(); //the record was updated, we need to refresh the contents of the softValidation LWC.
      }
    }
  }
  
  asyncJobsWorking = false;
  jobs = [];
  
  showComponent = true;
  componentContainerStyles = '';
  
  isIniting = true;
  skipFirstWireGetRecordEvent = false;
  reloadProcessId = null; //3/7/2024 - new property
  messages = [];
  evaluationResults = null;
  batchIndex = 0;
  evaluateRulesProcessIsAborted = false;
  
  rulesQualifiedForEvaluation = [];
  sObjectName = '';
  
  get showMessages(){
    return (this.showComponent && !this.isIniting && this.messages.length > 0);
  }
  
  connectedCallback() {
    if (typeof this.maxMessages === 'number'){
      this.showComponent = (this.maxMessages > 0);
    }
    
    if (typeof this.maxContainerHeight === 'number'){
      this.componentContainerStyles = 'max-height:' + this.maxContainerHeight + 'px;';
    }
    
    this.reload();
  }
  
  @api reload() {
    this.reset();
  
    if (this.recordId && this.showComponent === true){
      this.reloadProcessId = crypto.randomUUID(); //3/7/2024
      
      const promise = getRulesQualifiedForEvaluation({ params: {recordId: this.recordId} })
        .then(this.actionHandler.bind(this, this.getRulesQualifiedForEvaluationActionHandler.bind(this, this.reloadProcessId))) //3/7/2024 - pass this.reloadProcessId to the handler
        .catch(this.actionErrorHandler.bind(this, this.getRulesQualifiedForEvaluationActionHandler.bind(this, this.reloadProcessId))); //3/7/2024 - pass this.reloadProcessId to the handler
    
      this.trackAsyncJob(promise);
    } else {
      this.isIniting = false;
    }
  }
  
  getRulesQualifiedForEvaluationActionHandler(reloadProcessId, { success, data, errorMessage, errorDetails }) {
    if (reloadProcessId !== this.reloadProcessId) return; //3/7/2024
    
    if (success) {
      this.showComponent = data.showComponent;
      
      if (this.showComponent === true){
        this.sObjectName = data.sObjectName || '';
        this.rulesQualifiedForEvaluation = data.rules || [];
        
        this.evaluateRulesInBatches();
      }
    }
    else {
      let errorMessageAlert = this.getErrorAlertMessage(errorMessage, errorDetails, true);
      
      if (typeof errorMessageAlert === 'object' && errorMessageAlert !== null){
        errorMessageAlert.index = 0;
        this.messages.push(errorMessageAlert);
      }
  
      this.isIniting = false;
    }
  }
  
  evaluateRulesInBatches() {
    this.messages = [];
    this.evaluationResults = {};
    this.batchIndex = 0;
    this.evaluateRulesProcessIsAborted = false;
  
    let rulesToProcess = [...this.rulesQualifiedForEvaluation];
    let messagesLimit = (typeof this.maxMessages === 'number' ? this.maxMessages : 0);
    
    if (rulesToProcess.length > 0){
      for (let i = 0; i < MAX_PARALLEL_REQUESTS; i++){
        sendEvaluateRulesRequest.call(this);
      }
    }
    else{
      this.evaluateRulesInBatchesOnDone();
    }
    
    function sendEvaluateRulesRequest(){
      let rulesForRequest = [];
      
      if (this.evaluateRulesProcessIsAborted !== true){
        if (messagesLimit > 0 && rulesToProcess.length > 0){
          let processedRulesCount = this.evaluateRulesGetCountOfProcessedRules();
          
          if (processedRulesCount >= messagesLimit){
            this.evaluateRulesAbortProcess();
          }
          else{
            rulesForRequest = rulesToProcess.splice(0, BATCH_SIZE);
          }
        }
        else{
          rulesForRequest = rulesToProcess.splice(0, BATCH_SIZE);
        }
      }
      
      if (rulesForRequest.length > 0){
        for (let rule of rulesForRequest){
          this.evaluationResults[rule.id] = {status: 'evaluating', rule, evalData: null};
        }
  
        this.evaluateRulesAction(rulesForRequest)
          .then(() => {
            sendEvaluateRulesRequest.call(this);
          });
      }
      else{
        let rulesAreStillEvaluating = false;
        
        for (let rule of Object.values(this.evaluationResults)){
          if (rule.status === 'evaluating'){
            rulesAreStillEvaluating = true;
            break;
          }
        }
        
        if (rulesAreStillEvaluating === false){
          this.evaluateRulesInBatchesOnDone();
        }
      }
    }
  }
  
  evaluateRulesGetCountOfProcessedRules(){
    let processedRulesCount = 0;
    
    for (let rule of Object.values(this.evaluationResults)){
      if (rule.status === 'done' && rule.evalData){
        processedRulesCount++;
      }
    }
    
    return processedRulesCount;
  }
  
  evaluateRulesAbortProcess(){
    //console.log('aborting process');
    this.evaluateRulesProcessIsAborted = true;
  }
  
  evaluateRulesAction(rulesForRequest) {
    let reloadProcessId = this.reloadProcessId; //3/7/2024
    
    this.batchIndex++;
    
    return evaluateRules({ params: {recordId: this.recordId, sObjectName: this.sObjectName, rulesJSON: JSON.stringify(rulesForRequest), batchIndex: this.batchIndex} })
      .then(this.actionHandler.bind(this, this.evaluateRulesActionHandler.bind(this, { rulesForRequest, reloadProcessId }))) //3/7/2024 - pass this.reloadProcessId to the handler
      .catch(this.actionErrorHandler.bind(this, this.evaluateRulesActionHandler.bind(this, { rulesForRequest, reloadProcessId }))); //3/7/2024 - pass this.reloadProcessId to the handler
  }
  
  evaluateRulesActionHandler({ rulesForRequest, reloadProcessId }, { success, data, errorMessage, errorDetails }) {
    if (reloadProcessId !== this.reloadProcessId) return; //3/7/2024
    
    if (success) {
      for (let rule of rulesForRequest){
        let evalRule = this.evaluationResults[rule.id];
    
        if (evalRule){
          evalRule.status = 'done';
        }
      }
      
      for (let responseRule of Object.values(data)){
        let evalRule = this.evaluationResults[responseRule.id];
        
        if (evalRule){
          evalRule.evalData = {
            success: responseRule.success,
            
            ruleType: responseRule.type,
            ruleBodyHeight: responseRule.bodyHeight,
            ruleMsg: responseRule.msg,
            ruleCustomSettings: (typeof responseRule.customSettings === 'string' ? JSON.parse(responseRule.customSettings) : {}),
            
            errorMessage: responseRule.errorMessage,
            errorDetails: responseRule.errorDetails,
            isBatchError: false
          };
        }
      }
    }
    else{
      for (let rule of rulesForRequest){
        let evalRule = this.evaluationResults[rule.id];
    
        if (evalRule){
          evalRule.status = 'done';
          evalRule.evalData = { success, errorMessage, errorDetails, isBatchError: true };
        }
      }
    }
  }
  
  evaluateRulesInBatchesOnDone() {
    let messagesLimit = (typeof this.maxMessages === 'number' ? this.maxMessages : 0);
  
    for (let rule of this.rulesQualifiedForEvaluation){
      if (messagesLimit > 0 && this.messages.length >= messagesLimit){
        break;
      }
  
      let evalRule = this.evaluationResults[rule.id];
      if (evalRule && evalRule.status === 'done' && evalRule.evalData){
        let ruleAlertMessage = this.getRuleAlertMessage(rule, evalRule.evalData, (this.messages.length === 0));
  
        if (typeof ruleAlertMessage === 'object' && ruleAlertMessage !== null){
          ruleAlertMessage.index = this.messages.length;
          this.messages.push(ruleAlertMessage);
        }
      }
    }
    
    this.isIniting = false;
    
    if (this.recordIdForWireAdapter !== this.recordId) {
      this.skipFirstWireGetRecordEvent = true;
      this.recordIdForWireAdapter = this.recordId;
    }
  }
  
  getRuleAlertMessage(rule, evalData, isFirst){
    let ruleAlertMessage;
    
    if (rule && evalData){
      let ruleBodyHeight = (typeof evalData.ruleBodyHeight === 'number' ? evalData.ruleBodyHeight : 0);
      
      if (evalData.success === true){
        if (evalData.ruleType === 'Custom'){
          ruleAlertMessage = {
            type: evalData.ruleType,
            cssClasses: 'notify-alert-container' + (isFirst === true ? ' first' : ''),
            cssStyles: (typeof evalData.ruleCustomSettings.backgroundColor === 'string' ? 'background-color:' + evalData.ruleCustomSettings.backgroundColor + ';' : ''),
            iconName: (evalData.ruleCustomSettings.iconName ? 'utility:' + evalData.ruleCustomSettings.iconName : ''),
            iconAlternativeText: '',
            iconTitle: '',
            iconVariant: (evalData.ruleCustomSettings.iconVariant || ''),
            msgBodyCssStyles: (ruleBodyHeight > 0 ? 'max-height:' + ruleBodyHeight + 'px;' : ''),
            msgRichText: evalData.ruleMsg
          };
        }
        else{
          let alertMsgParams = MSG_TYPE_PARAMS[evalData.ruleType];
  
          if (alertMsgParams){
            ruleAlertMessage = {
              type: evalData.ruleType,
              cssClasses: alertMsgParams.cssClasses + (isFirst === true ? ' first' : ''),
              cssStyles: 'background-color:' + alertMsgParams.backgroundColor + ';',
              iconName: alertMsgParams.iconName,
              iconAlternativeText: alertMsgParams.iconAlternativeText,
              iconTitle: alertMsgParams.iconTitle,
              iconVariant: alertMsgParams.iconVariant,
              msgBodyCssStyles: (ruleBodyHeight > 0 ? 'max-height:' + ruleBodyHeight + 'px;' : ''),
              msgRichText: evalData.ruleMsg
            };
          }
        }
      }
      else{
        ruleAlertMessage = this.getErrorAlertMessage(evalData.errorMessage, evalData.errorDetails, isFirst, rule);
      }
    }
    
    return ruleAlertMessage;
  }
  
  getErrorAlertMessage(errorMessage, errorDetails, isFirst, rule){
    let errorMessageTemplateGeneric = '<p><b style="font-size: 12px; color: rgb(255, 255, 255);">Soft Validation Error</b><span style="color: rgb(255, 255, 255);">: {errMsg}</span></p>';
    let errorMessageTemplateRule = '<p><b style="font-size: 12px; color: rgb(255, 255, 255);">Error occurred when processing Soft Validation Rule "<a href="/{ruleId}" target="_blank">{ruleName}</a>"</b><span style="color: rgb(255, 255, 255);">: {errMsg}</span></p>';
    let errorDetailsTemplate = '<p><br></p><p><span style="color: rgb(255, 255, 255);">{errDetails}</span></p>';
    let errorAlertMessage;
    
    if (typeof errorMessage === 'string' && errorMessage.length > 0){
      let errorMessageHTML;
      
      if (rule){
        errorMessageHTML = errorMessageTemplateRule.replace('{ruleId}', rule.id).replace('{ruleName}', rule.name).replace('{errMsg}', this.escapeHTML(errorMessage));
      }
      else{
        errorMessageHTML = errorMessageTemplateGeneric.replace('{errMsg}', this.escapeHTML(errorMessage));
      }
      
      if (typeof errorDetails === 'string' && errorDetails.length > 0 && errorDetails !== '()'){
        errorMessageHTML += errorDetailsTemplate.replace('{errDetails}', this.escapeHTML(errorDetails));
      }
  
      let infoMsgType = MSG_TYPE_PARAMS['Error'];
      
      errorAlertMessage = {
        type: 'Error',
        cssClasses: infoMsgType.cssClasses + (isFirst === true ? ' first' : ''),
        cssStyles: 'background-color:' + infoMsgType.backgroundColor + ';',
        iconName: infoMsgType.iconName,
        iconAlternativeText: infoMsgType.iconAlternativeText,
        iconTitle: infoMsgType.iconTitle,
        iconVariant: infoMsgType.iconVariant,
        msgBodyCssStyles: 'max-height:70px;',
        msgRichText: errorMessageHTML
      };
    }
    
    return errorAlertMessage;
  }
  
  reset() {
    this.isIniting = true;
    this.messages = [];
    this.evaluationResults = null;
    this.batchIndex = 0;
    this.evaluateRulesProcessIsAborted = false;
    this.reloadProcessId = null; //3/7/2024
    
    this.rulesQualifiedForEvaluation = [];
    this.sObjectName = '';
  }
  
  actionHandler(doneCallback, resp, error) {
    let _error = '';
    let _errorDetails = '';
    let result = { success: true };

    if (resp) {
      if (resp.success || resp.success === undefined) {
        result.data = (typeof resp.result === 'undefined' ? resp : resp.result);
      }
      else {
        _error = resp.message;
        _errorDetails = (resp.technicalData ? (resp.technicalData.stackTrace || '') : '');
      }
    }
    else {
      if (typeof error === 'object' && error !== null){
        if (typeof error.body === 'object' && error.body !== null){
          _error = (typeof error.body.exceptionType === 'string' ? error.body.exceptionType + ': ' : '') + (typeof error.body.message === 'string' ? error.body.message : '');
          _errorDetails = (typeof error.body.stackTrace === 'string' ? error.body.stackTrace : '');
        }
        else if (typeof error.message === 'string'){
          _error = error.message;
        }
      }
      else if (typeof error === 'string'){
        _error = error;
      }

      if (!_error) _error = 'Internal Server Error';
    }

    if (_error) {
      Object.assign(result, { success: false, errorMessage: _error, errorDetails: _errorDetails });
    }

    doneCallback.call(this, result);
  }
  
  actionErrorHandler(doneCallback, error) {
    this.actionHandler(doneCallback, null, error);
  }
  
  trackAsyncJob(promise) {
    if (Array.isArray(promise))
      this.jobs = [...this.jobs, ...promise];
    else if (promise)
      this.jobs.push(promise);
    
    if (!this.trackerLocked) {
      this.trackerLocked = true;
      this.asyncJobsWorking = true;
      
      Promise.all(this.jobs).finally(() => {
        this.trackerLocked = false;
        if (this.jobs.length) {
          this.trackAsyncJob();
        }
        else {
          this.asyncJobsWorking = false;
        }
      });
      
      this.jobs = [];
    }
  }
  
  escapeHTML(str){
    if (typeof str !== 'string') return str;
    
    return str.replace(
      /[&<>'"]/g,
      tag =>
        ({
          '&': '&amp;',
          '<': '&lt;',
          '>': '&gt;',
          "'": '&#39;',
          '"': '&quot;'
        }[tag] || tag)
    );
  }
}