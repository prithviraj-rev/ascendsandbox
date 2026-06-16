import {wire, api, track, LightningElement} from 'lwc';
import loadRule from '@salesforce/apex/SoftValidationMsgEditorController.loadRule';
import saveRule from '@salesforce/apex/SoftValidationMsgEditorController.saveRule';

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

export default class SoftValidationMessageEditor extends LightningElement {
  @api recordId;
  @track rule;
  
  asyncJobsWorking = false;
  jobs = [];
  isLoading = false;
  isIniting = true;
  formIsSaved = true;
  richTextEditorContainerCssClasses = '';

  @track pageMessages = [];
  get hasPageMessages(){
    return (this.pageMessages.length > 0);
  }
  
  ruleMessageTypeOptions = [
    {label: 'Info', value: 'Info'},
    {label: 'Success', value: 'Success'},
    {label: 'Warning', value: 'Warning'},
    {label: 'Error', value: 'Error'},
    {label: 'Custom', value: 'Custom'}
  ];
  
  iconVariantOptions = [
    {label: '--None--', value: ''},
    {label: 'Inverse', value: 'inverse'},
    {label: 'Success', value: 'success'},
    {label: 'Warning', value: 'warning'},
    {label: 'Error', value: 'error'}
  ];
  
  ruleMsgIsCustom = false;
  ruleMsgCssClasses = '';
  ruleMsgCssStyles = '';
  ruleMsgIconName = '';
  ruleMsgIconNameUserInput = '';
  ruleMsgIconAlternativeText = '';
  ruleMsgIconTitle = '';
  ruleMsgIconVariant = '';
  ruleMsgBackgroundColor = '';
  
  connectedCallback(){
    this.reload();
  }
  
  reload(){
    this.reset();
    
    if (this.recordId){
      this.richTextEditorContainerCssClasses = 'rich-text-editor-' + this.recordId;
      
      const promise = loadRule({recordId: this.recordId})
        .then(this.actionHandler.bind(this, this.loadRuleActionHandler))
        .catch(this.actionErrorHandler.bind(this, this.loadRuleActionHandler));

      this.trackAsyncJob(promise);
    }
    else{
      this.isIniting = false;
    }
  }
  
  refreshRuleMsgAttributes(){
    let msgBackgroundColor;
    
    if (this.rule.MessageType__c === 'Custom'){
      this.ruleMsgIsCustom = true;
  
      this.ruleMsgCssClasses = 'notify-alert-container';
      this.ruleMsgCssStyles = '';
      this.ruleMsgIconName = '';
      this.ruleMsgIconNameUserInput = '';
      this.ruleMsgIconAlternativeText = '';
      this.ruleMsgIconTitle = '';
      this.ruleMsgIconVariant = '';
      this.ruleMsgBackgroundColor = '';
    }
    else{
      this.ruleMsgIsCustom = false;
  
      let alertMsgParams = MSG_TYPE_PARAMS[this.rule.MessageType__c];
  
      this.ruleMsgCssClasses = alertMsgParams.cssClasses;
      this.ruleMsgCssStyles = 'background-color:' + alertMsgParams.backgroundColor + ';';
      this.ruleMsgIconName = alertMsgParams.iconName;
      this.ruleMsgIconNameUserInput = '';
      this.ruleMsgIconAlternativeText = alertMsgParams.iconAlternativeText;
      this.ruleMsgIconTitle = alertMsgParams.iconTitle;
      this.ruleMsgIconVariant = alertMsgParams.iconVariant;
      this.ruleMsgBackgroundColor = '';
  
      msgBackgroundColor = alertMsgParams.backgroundColor;
    }
  
    this.updateRichTextEditorBackgroundColor(msgBackgroundColor);
  }
  
  updateRuleMsgBackgroundColor(color){
    this.ruleMsgCssStyles = '';
    
    if (color){
      this.ruleMsgCssStyles = 'background-color:' + color + ';';
    }
  
    this.updateRichTextEditorBackgroundColor(color);
  }
  
  updateRichTextEditorBackgroundColor(color){
    let style;
  
    if (color){
      style = this.template.ownerDocument.createElement('style');
      style.innerText = '.' + this.richTextEditorContainerCssClasses + ' div.slds-rich-text-area__content{background-color:' + color + ';}';
    }
  
    let stylesContainer = this.template.querySelector('.standard-styles-override');
  
    if (stylesContainer){
      let child = stylesContainer.lastElementChild;
    
      while (child){
        stylesContainer.removeChild(child);
        child = stylesContainer.lastElementChild;
      }
    
      if (style) stylesContainer.appendChild(style);
    }
  }
  
  handleInputChange(event){
    let targetName = event.target.name;
    let value = event.detail.value;
    
    switch (targetName){
      case 'messageType':
        this.rule.MessageType__c = value;
        this.refreshRuleMsgAttributes();
        break;
      case 'messageMaxHeight':
        if (typeof value === 'string' && value.length > 0){
          let messageMaxHeightInt = parseInt(value, 10);
          if (messageMaxHeightInt >= 0 && messageMaxHeightInt <= 9999) this.rule.MessageMaxHeight__c = messageMaxHeightInt;
        }
        else{
          this.rule.MessageMaxHeight__c = null;
        }
        break;
      case 'backgroundColor':
        this.ruleMsgBackgroundColor = (value && value.startsWith('#') ? value : '');
        this.updateRuleMsgBackgroundColor(this.ruleMsgBackgroundColor);
        break;
      case 'iconName':
        this.ruleMsgIconNameUserInput = value;
        this.ruleMsgIconName = (this.ruleMsgIconNameUserInput ? 'utility:' + this.ruleMsgIconNameUserInput : '');
        break;
      case 'iconVariant':
        this.ruleMsgIconVariant = value;
        break;
    }
  
    this.pageMessages.length = 0;
    this.formIsSaved = false;
    this.makeUnsavedChanges();
  }
  
  handleMsgChange(event){
    this.rule.Message__c = event.detail.value;
    this.pageMessages.length = 0;
    this.formIsSaved = false;
    this.makeUnsavedChanges();
  }
  
  handleSaveBtnClick(event){
    this.save();
  }
  
  @api save(){
    this.pageMessages.length = 0;
  
    if (!this.rule.MessageType__c || !this.rule.Message__c){
      let errorMessageAlert = this.getErrorAlertMessage('Please complete all required fields.', undefined, true);
    
      this.pageMessages.push(errorMessageAlert);
      errorMessageAlert.index = (this.pageMessages.length - 1);
      this.makeUnsavedChanges();
    }
    else{
      let params = {
        ruleId: this.recordId,
        messageType: this.rule.MessageType__c,
        messageMaxHeight: this.rule.MessageMaxHeight__c,
        message: this.rule.Message__c
      };
    
      if (this.rule.MessageType__c === 'Custom'){
        params.backgroundColor = this.ruleMsgBackgroundColor;
        params.iconName = this.ruleMsgIconNameUserInput;
        params.iconVariant = this.ruleMsgIconVariant;
      }
    
      const promise = saveRule({params})
        .then(this.actionHandler.bind(this, this.saveRuleActionHandler))
        .catch(this.actionErrorHandler.bind(this, this.saveRuleActionHandler));
    
      this.trackAsyncJob(promise);
      this.isLoading = true;
    }
  }
  
  makeUnsavedChanges(){
    let makeUnsavedChangesEvt = new CustomEvent('makeunsavedchanges');
    this.dispatchEvent(makeUnsavedChangesEvt);
  }
  
  clearUnsavedChanges(){
    let clearUnsavedChangesEvt = new CustomEvent('clearunsavedchanges');
    this.dispatchEvent(clearUnsavedChangesEvt);
  }
  
  loadRuleActionHandler({ success, data, errorMessage, errorDetails }) {
    let errorMessageAlert;
    
    if (success) {
      let rules = JSON.parse(data);
      
      if (Array.isArray(rules) && rules.length > 0){
        this.rule = rules[0];
  
        if (!this.rule.MessageType__c) this.rule.MessageType__c = 'Info';
        
        if (this.rule.MessageType__c === 'Custom'){
          this.ruleMsgIsCustom = true;
          
          if (this.rule.MessageCustomSettings__c){
            let msgCustomSettings = JSON.parse(this.rule.MessageCustomSettings__c);
  
            this.ruleMsgCssClasses = 'notify-alert-container';
            this.ruleMsgCssStyles = '';
            this.ruleMsgIconNameUserInput = msgCustomSettings.iconName || '';
            this.ruleMsgIconName = (this.ruleMsgIconNameUserInput ? 'utility:' + this.ruleMsgIconNameUserInput : '');
            this.ruleMsgIconAlternativeText = '';
            this.ruleMsgIconTitle = '';
            this.ruleMsgIconVariant = msgCustomSettings.iconVariant || '';
            this.ruleMsgBackgroundColor = (msgCustomSettings.backgroundColor && msgCustomSettings.backgroundColor.startsWith('#') ? msgCustomSettings.backgroundColor : '');
            
            this.updateRuleMsgBackgroundColor(this.ruleMsgBackgroundColor);
          }
        }
        else{
          this.refreshRuleMsgAttributes();
        }
      }
      else{
        errorMessageAlert = this.getErrorAlertMessage('record not found for id = ' + this.recordId, undefined, true);
      }
    }
    else {
      errorMessageAlert = this.getErrorAlertMessage(errorMessage, errorDetails, true);
    }
    
    if (typeof errorMessageAlert === 'object' && errorMessageAlert !== null){
      this.pageMessages.push(errorMessageAlert);
      errorMessageAlert.index = (this.pageMessages.length - 1);
    }
    
    this.isIniting = false;
  }
  
  saveRuleActionHandler({ success, data, errorMessage, errorDetails }) {
    let msg;
    
    if (success){
      let infoMsgType = MSG_TYPE_PARAMS['Success'];
      
      msg = {
        type: 'Success',
        cssClasses: infoMsgType.cssClasses + ' first',
        cssStyles: 'background-color:' + infoMsgType.backgroundColor + ';',
        iconName: infoMsgType.iconName,
        iconAlternativeText: infoMsgType.iconAlternativeText,
        iconTitle: infoMsgType.iconTitle,
        iconVariant: infoMsgType.iconVariant,
        msgBodyCssStyles: '',
        msgRichText: '<p><span style="color: rgb(255, 255, 255);">Changes in Message Configuration have been saved successfully!</span></p>'
      };
  
      this.formIsSaved = true;
      this.clearUnsavedChanges();
    }
    else{
      msg = this.getErrorAlertMessage(errorMessage, errorDetails, true);
      this.makeUnsavedChanges();
    }
    
    if (typeof msg === 'object' && msg !== null){
      this.pageMessages.push(msg);
      msg.index = (this.pageMessages.length - 1);
    }
    
    this.isLoading = false;
  }
  
  reset(){
    this.isIniting = true;
    this.isLoading = false;
    this.formIsSaved = true;
    this.pageMessages = [];
    this.richTextEditorContainerCssClasses = '';
  
    this.rule = null;
  
    this.ruleMsgIsCustom = false;
    this.ruleMsgCssClasses = '';
    this.ruleMsgCssStyles = '';
    this.ruleMsgIconName = '';
    this.ruleMsgIconNameUserInput = '';
    this.ruleMsgIconAlternativeText = '';
    this.ruleMsgIconTitle = '';
    this.ruleMsgIconVariant = '';
    this.ruleMsgBackgroundColor = '';
  }
  
  getErrorAlertMessage(errorMessage, errorDetails, isFirst){
    let errorMessageTemplateGeneric = '<p><b style="font-size: 12px; color: rgb(255, 255, 255);">Error</b><span style="color: rgb(255, 255, 255);">: {errMsg}</span></p>';
    let errorDetailsTemplate = '<p><br></p><p><span style="color: rgb(255, 255, 255);">{errDetails}</span></p>';
    let errorAlertMessage;
    
    if (typeof errorMessage === 'string' && errorMessage.length > 0){
      let errorMessageHTML;
  
      errorMessageHTML = errorMessageTemplateGeneric.replace('{errMsg}', this.escapeHTML(errorMessage));
      
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
        msgBodyCssStyles: '',
        msgRichText: errorMessageHTML
      };
    }
    
    return errorAlertMessage;
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