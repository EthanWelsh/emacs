//$Id: adom.js 6864 2011-02-18 23:59:21Z tv.raman.tv $
// <Helper: beget

// useful if we use the prototypical pattern, rather than classical inheritance
if (typeof Object.beget !== 'function') {
  Object.beget = function (o) {
    var F = function () {};
    F.prototype = o;
    return new F();
  };
}

// >
// <Class ADom

/*
 * ADOM: Holds a proxy to a DOM
 * Provides convenience methods for obtaining custom views
 * Constructor takes  the   document to view as argument
 */

ADom = function(document) {
    this.document_ = document;
    document.adom = this;
    this.root_ = document.documentElement;
    this.current_ = document.documentElement;
    this.view_ = null;
};

// >
// < Navigators:

/*
 * Reset view.
 * Resets current to point at the root.
 * @return {node} current node.
 */
ADom.prototype.reset = function() {
    this.root_ = this.document_.documentElement;
    return this.current_ = this.root_;
};

/*
 * next: Move to next sibling.
 * @return {node} current node.
 */
ADom.prototype.next = function() {
    return this.current_ = this.current_.nextSibling;
};

/*
 * previous: Move to previous sibling.
 * @return {node} current node.
 */
ADom.prototype.previous = function() {
    return this.current_ = this.current_.previousSibling;
};

/*
 * up: Move to parent.
 * @return {node} current node.
 */
ADom.prototype.up = function() {
    return this.current_ = this.parentNode;
};

/*
 * down: Move to first child
 * @return {node} current node.
 */
ADom.prototype.down = function() {
    return this.current_ = this.current_.firstChild;
};

/*
 * first: Move to first sibling
 * @return {node} current node.
 */
ADom.prototype.first = function() {
    return this.current_ = this.current_.parentNode.firstChild;
};

/*
 * last: Move to last sibling.
 * @return {node} current node.
 */
ADom.prototype.last = function() {
    return this.current_ = this.current_.parentNode.lastChild;
};

/*
 * Move to  document body
 * @return {node} current node.
 */
ADom.prototype.body = function() {
    return this.current_ = this.document_.body;
};


/*
 * Move to  element identified by id
 * @return {node} current node.
 */
ADom.prototype.selectId = function(elementId) {
    return this.current_ = this.document_.getElementById(elementId);
};

// >
// <Summarizers:

/*
 * base: Return appropriately encoded <base .
 * @return: {String} HTML base element.
 */
ADom.prototype.base = function() {
    return '<base href=\"' + this.document_.baseURI + '\"/>\n';
};

/*
 * Return HTML for current node.
 * Produces a <base ../> if optional boolean flag gen_base is true.
 *@Return {string}; HTML
 */
ADom.prototype.html = function(gen_base) {
    var html = '';
    if (gen_base) {
        html += this.base();
    }
    html += '<' + this.current_.tagName;
    if (this.current_.value !== undefined) {
      html += ' value' + '=';
      html += '\"' + this.current_.value + '\"\n';
    }
    var map = this.current_.attributes;
    if (map instanceof NamedNodeMap) {
        for (var i = 0; i < map.length; i++) {
            html += ' ' + map[i].name + '=';
            html += '\"' + map[i].value + '\"\n';
        }
    }
    if (this.current_.childNodes.length === 0) {
        return html += '/>\n';
    } else {
        html += '>\n' + this.current_.innerHTML;
        html += '</' + this.current_.tagName + '>\n';
        return html;
    }
};

/*
 * summarize: Summarize current node.
 * @Return {string};
 */
ADom.prototype.summarize = function() {
    var summary = this.current_.tagName + ' ';
    summary += 'has ' + this.current_.childNodes.length + 'children ';
    summary += ' with ' + this.current_.innerHTML.length + ' bytes of content.';
    return summary;
};

/*
 * title: return document title
 * @Return  {string}
 */
ADom.prototype.title = function() {
    return this.document_.title;
};

/*
 * url: Return base URL of document.
 * @return {String} url
 */
ADom.prototype.url = function() {
    return this.document_.baseURI;
};

/*
 * Return document being viewed.
 */
ADom.prototype.document = function() {
    return this.document_;
};


/*
 * Return root of document being viewed.
 */
ADom.prototype.root = function() {
    return this.root_;
};


/*
 * Return the current node being viewed.
 */
ADom.prototype.current = function() {
    return this.current_;
};

// >
// <RingBuffer:

/*
 *  Implements iteration.
 */
var RingBuffer = function(list) {
    this.list_ = list;
    this.index_ = -1;
    this.len_ = list.length;
};

/*
 * item: Return item at specified index.
 * @return: node.
 */
RingBuffer.prototype.item = function(index) {
    return this.list_.item(this.index);
};


RingBuffer.prototype.next = function() {
    if (this.index_ == this.len_ - 1) {
        this.index_ = -1;
    }
    this.index_++;
    return this.list_.item(this.index_);
};

RingBuffer.prototype.previous = function() {
    if (this.index_ === -1 || this.index_ === 0) {
        this.index_ = this.len_;
    }
    this.index_--;
    return this.list_.item(this.index_);
};

// >
// <XPathRingBuffer:

/*
 *  Implements RingBuffer.
 */
var XPathRingBuffer = function(nodes) {
    this.list_ = nodes;
    this.index_ = -1;
    this.len_ = nodes.snapshotLength;
};


/*
 * item: Return item at specified index.
 * @return: node.
 */
XPathRingBuffer.prototype.item = function(index) {
    return this.list_.snapshotItem(this.index);
};


XPathRingBuffer.prototype.next = function() {
    if (this.index_ == this.len_ - 1) {
        this.index_ = -1;
    }
    this.index_++;
    return this.list_.snapshotItem(this.index_);
};

XPathRingBuffer.prototype.previous = function() {
    if (this.index_ === -1 || this.index_ === 0) {
        this.index_ = this.len_;
    }
    this.index_--;
    return this.list_.snapshotItem(this.index_);
};

// >
// <XPath:

/*
 * filter: Apply XPath selector to create a filtered view.
 * @return {RingBuffer} of selected nodes suitable for use by visit()
 */

ADom.prototype.filter = function(xpath) {
    var start = this.current_ || this.root_;
    try {
      var snap =
          this.document_.evaluate(xpath,
                                  start,
                                  null, // no namespace resolver
                                  XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE,
                                  null); // no previous results
    return this.view_ = new XPathRingBuffer(snap);
    } catch (err) {
      repl.print("Error evaluating XPath '" + xpath + "': " + err);
      return null;
    }
};

// >
// <Viewers And Visitors:

/*
 * traverse: Traverse nodes that match test and apply action.
 * Arguments:
 * node: Node where we start traversing.
 * test: Predicate
 * Action: Visit action
 * @return: void
 */

ADom.prototype.traverse = function(node, test, action) {
  if (node.nodeType == document.ELEMENT_NODE) {
    if (test(node)) action(node);
    var child = node.firstChild;
    while (child) this.traverse(child, test, action);
  }
};

/*
 * Set view to forms array
 * Return forms array.
 */
ADom.prototype.forms = function() {
    this.view_ = new RingBuffer(this.document_.forms);
    return this.view_;
};
/*
 * locate: set view_ to RingBuffer of elements found by name
 */
ADom.prototype.locate = function(tagName) {
    var start = this.current_ || this.root_;
    return this.view_ = new RingBuffer(start.getElementsByTagName(tagName));
};

/*
 * visit: visit each node in view_ in turn.
 * Optional argument dir if specified visits in the reverse direction.
 */
ADom.prototype.visit = function(dir) {
    if (dir) {
        this.current_ = this.view_.previous();
    } else {
        this.current_ = this.view_.next();
    }
    // skip empties
    if (this.current_.childNodes.length === 0 && this.current_.attributes.length === 0) {
        return this.visit(dir);
    } else {
        return this.current_;
    }
};


/*
 * view: Return HTML for all nodes in view_ array
 * @return: {String} HTML
 */
ADom.prototype.view = function() {
    if (this.view_ === null) {
        return this.current_.html(true);
    }
    var html = this.base();
    var len = this.view_.len_;
    for (var i = 0; i < len; i++) {
        this.visit();
        html += this.html();
        html += '<br/>';
    }
    return html;
};

// >
// < Eventing:

/*
 * target: Return a suitable target for sending keypresses
 * We need to know where the focus is,
 * for now, we depend on Fire Vox  doing the work for us.
 * Uses Fire Vox global CLC_SR_CurrentAtomicObject
 * that gets set by Fire Vox whenever a focus event occurs.
 * If that variable is 0 i.e. unset,
 * we return document.body
 * @Return: Node
 */

ADom.prototype.target = function() {
  if (!CLC_SR_CurrentAtomicObject){
      CLC_SR_CurrentAtomicObject =
CLC_GetFirstAtomicObject(CLC_Window().document.body);
      }
  return CLC_SR_CurrentAtomicObject || this.document_.body;
};

/**
 * Dispatches a left click event on the element that is the targetNode.
 * @param {Node} targetNode The target node of this operation.
 * @return {Null}
 */
ADom.prototype.click = function(targetNode){
  var evt = document.createEvent('MouseEvents');
  evt.initMouseEvent('click', true, true, document.defaultView,
                     1, 0, 0, 0, 0, false, false, false, false, 0, null);
  targetNode.dispatchEvent(evt);
};

  /*
   * send a key
   */

ADom.prototype.keyPress = function(targetNode,
                                   theKey,
                                   holdCtrl, holdAlt, holdShift){
  var keyCode = 0;
  var charCode = 0;
  if (theKey == 'ENTER'){
    keyCode = 13;
  } else if (theKey == 'TAB'){
    keyCode = 9;
  } else if (theKey.length == 1){
    charCode = theKey.charCodeAt(0);
    keyCode = charCode;
  }
  var evt = document.createEvent('KeyboardEvent');
  evt.initKeyEvent('keypress', true, true,
  this.document_.defaultView, holdCtrl,
                   holdAlt, holdShift, false, keyCode, charCode);
  targetNode.dispatchEvent(evt);
};


  /*
   * send a key down
   */

ADom.prototype.keyDown = function(targetNode,
                                   theKey,
                                   holdCtrl, holdAlt, holdShift){
  var keyCode = 0;
  var charCode = 0;
  if (theKey == 'ENTER'){
    keyCode = 13;
  } else if (theKey == 'TAB'){
    keyCode = 9;
  } else if (theKey.length == 1){
    charCode = theKey.charCodeAt(0);
  }
  var evt = document.createEvent('KeyboardEvent');
  evt.initKeyEvent('keydown', true, true, null, holdCtrl,
                   holdAlt, holdShift, false, keyCode, charCode);
  targetNode.dispatchEvent(evt);
};



  /*
   * send a key up
   */

ADom.prototype.keyUp = function(targetNode,
                                   theKey,
                                   holdCtrl, holdAlt, holdShift){
  var keyCode = 0;
  var charCode = 0;
  if (theKey == 'ENTER'){
    keyCode = 13;
  } else if (theKey == 'TAB'){
    keyCode = 9;
  } else if (theKey.length == 1){
    charCode = theKey.charCodeAt(0);
  }
  var evt = document.createEvent('KeyboardEvent');
  evt.initKeyEvent('keyup', true, true, null, holdCtrl,
                   holdAlt, holdShift, false, keyCode, charCode);
  targetNode.dispatchEvent(evt);
};

// >
// < A11y Reflection:

// >
// <WebSearch:

/*
 * Perform a webSearch:
 */
ADom.prototype.webSearch = function(q) {
  var ub = document.getElementById('urlbar');
  ub.value = q;
handleURLBarCommand();
};

// >
// <repl hookup

/*
 * Update adom pointer in repl to point to current document.
 * @return {ADom}
 */
repl.updateADom = function()  {
    if (content.document.adom == undefined) {
        // constructor caches adom in content.document
        repl.adom = new ADom(content.document);
    } else {
      repl.adom = content.document.adom;
    }
    return repl.adom;
};

// >
// <end of file



// local variables:
// folded-file: t
// end:

// >
