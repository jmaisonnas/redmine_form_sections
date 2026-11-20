'use strict';

// Minimal DOM fixture for exercising node moves and restoring their exact order.
class FixtureNode {
  constructor(tag, className = '') {
    this.tag = tag;
    this.className = className;
    this.dataset = {};
    this.nodes = [];
    this.parentNode = null;
    this.listeners = {};
  }

  get classList() {
    const classes = this.className.split(' ').filter(Boolean);
    classes.toggle = (name, force) => {
      this.className = [...classes.filter(value => value !== name), ...(force ? [name] : [])].join(' ');
      this.afterClassToggle?.();
    };
    return classes;
  }
  get parentElement() { return this.parentNode; }
  get children() { return this.nodes.filter(node => node.tag !== '#comment'); }
  get firstElementChild() { return this.children[0]; }
  get innerText() { return [this.textContent || '', ...this.children.map(child => child.innerText)].join(''); }

  getAttribute(attribute) { return this[attribute] ?? null; }
  getClientRects() { return this.rendered === false ? [] : [{}]; }

  addEventListener(type, callback) { (this.listeners[type] ||= []).push(callback); }
  dispatchEvent(event) { (this.listeners[event.type] || []).forEach(callback => callback(event)); }

  matches(selector) {
    if (selector.startsWith('#')) return this.id === selector.slice(1);
    if (selector.startsWith('.')) return selector.slice(1).split('.').every(name => this.classList.includes(name));
    if (selector === 'input[type="checkbox"]') return this.tag === 'input' && this.type === 'checkbox';
    return this.tag === selector;
  }

  querySelectorAll(selector) {
    const descendants = this.children.flatMap(child => [child, ...child.querySelectorAll('*')]);
    if (selector === '*') return descendants;

    const selectors = selector.split(', ');
    return descendants.filter(child => selectors.some(part => child.matches(part)));
  }

  querySelector(selector) {
    if (!selector.startsWith(':scope > ')) return this.querySelectorAll(selector)[0];

    return selector.split(' > ').slice(1).reduce((parent, part) =>
      parent?.children.find(child => child.matches(part)), this);
  }

  appendChild(node) { return this.insertBefore(node, null); }

  insertBefore(node, reference) {
    node.remove();
    const index = reference ? this.nodes.indexOf(reference) : this.nodes.length;
    if (index === -1) throw new Error('Invalid reference');
    this.nodes.splice(index, 0, node);
    node.parentNode = this;
    return node;
  }

  remove() {
    if (!this.parentNode) return;
    this.parentNode.nodes.splice(this.parentNode.nodes.indexOf(this), 1);
    this.parentNode = null;
  }

  replaceWith(node) {
    this.parentNode.insertBefore(node, this);
    this.remove();
  }
}

function issueFixture(sections, { ordinary = [1, 2], wide = [3, 4] } = {}) {
  const document = new FixtureNode('document');
  document.defaultView = new FixtureNode('window');
  document.createElement = tag => new FixtureNode(tag);
  document.createComment = () => new FixtureNode('#comment');
  const add = (parent, tag, classes) => parent.appendChild(new FixtureNode(tag, classes));
  const details = add(document, 'div', 'issue details');
  const attributes = add(details, 'div', 'attributes');
  const core = add(attributes, 'div', 'splitcontent');
  const coreLeft = add(core, 'div', 'splitcontentleft');
  add(coreLeft, 'div', 'attribute status');
  add(core, 'div', 'splitcontentright');
  const fields = {};

  if (ordinary.length) {
    const block = add(attributes, 'div', 'splitcontent');
    const left = add(block, 'div', 'splitcontentleft');
    const right = add(block, 'div', 'splitcontentright');
    ordinary.forEach((id, index) => {
      const node = fields[id] = add(index < Math.ceil(ordinary.length / 2) ? left : right, 'div', `attribute cf_${id}`);
      add(node, 'div', 'label');
      add(node, 'div', 'value');
    });
  }
  const start = add(attributes, 'template');
  start.id = 'rfs-issue-show-details';
  start.dataset = { sections: JSON.stringify(sections), otherFields: 'Autres champs' };

  const descriptionSeparator = add(details, 'hr');
  const description = add(details, 'div', 'description');
  const attachmentsSeparator = add(details, 'hr');
  const attachments = add(details, 'div', 'attachments');
  const attachmentLink = add(attachments, 'a');
  wide.forEach(id => {
    const node = fields[id] = add(details, 'div', `attribute cf_${id}`);
    add(node, 'hr');
    add(add(node, 'p'), 'strong');
    add(add(node, 'div', 'value'), 'a');
  });
  const end = add(details, 'template');
  end.id = 'rfs-issue-show-description-bottom';
  end.content = new FixtureNode('fragment');
  const filter = add(end.content, 'label', 'rfs-show-filter');
  filter.cloneNode = () => {
    const label = new FixtureNode('label', 'rfs-show-filter');
    add(label, 'input').type = 'checkbox';
    return label;
  };

  return { document, details, attributes, start, end, fields,
           descriptionSeparator, description, attachmentsSeparator, attachments, attachmentLink };
}

function testIssueShowLayout(arrangeIssueShowFields) {
  function check(condition, description) {
    if (!condition) throw new Error(description);
  }
  function snapshot(node) {
    return JSON.stringify([node.tag, node.id, node.className, node.textContent, node.checked, node.dataset, node.nodes.map(snapshot)]);
  }

  const mixed = issueFixture([
    { title: '<b>Mixed</b>', left: [1, 3], right: [] },
    { title: 'Omitted', left: [5] }
  ]);
  const originalValue = mixed.fields[3].querySelector(':scope > .value');
  arrangeIssueShowFields(mixed.document);
  const [container] = mixed.document.querySelectorAll('.rfs-show-sections');
  check(mixed.attributes.children[1] === container, 'Sections replace the native ordinary block');
  const [control, section, other] = container.children;
  check(control.matches('.rfs-show-filter') && container.children.length === 3, 'Omitted fields create no section');
  check(section.children[0].textContent === '<b>Mixed</b>' && !section.children[0].children.length, 'Title is text');
  check(section.querySelector(':scope > .splitcontent > .splitcontentleft').firstElementChild === mixed.fields[1],
        'Ordinary field in configured column');
  check(section.querySelector(':scope > .splitcontent > .splitcontentright').children.length === 0,
        'Explicit empty right column');
  check(section.children[2].firstElementChild === mixed.fields[3] && originalValue.firstElementChild.matches('a'),
        'Original full-width node and its link below the columns');
  check(other.children[0].textContent === 'Autres champs' && other.querySelectorAll('.attribute').length === 2,
        'Unclassified ordinary and full-width fields in Other fields');
  check(mixed.details.children.slice(0, 5).every((node, index) => node === [
    mixed.attributes, mixed.descriptionSeparator, mixed.description, mixed.attachmentsSeparator, mixed.attachments
  ][index]) && mixed.attachments.firstElementChild === mixed.attachmentLink, 'Native description and attachments stay in place');
  check(Object.entries(mixed.fields).every(([id, node]) => {
    const matches = mixed.document.querySelectorAll(`.attribute.cf_${id}`);
    return matches.length === 1 && matches[0] === node;
  }), 'Every field appears exactly once with the original node');
  const grouped = snapshot(mixed.document);
  arrangeIssueShowFields(mixed.document);
  check(snapshot(mixed.document) === grouped, 'Second execution leaves the DOM intact');

  const reader = issueFixture([
    { title: 'Restricted section', left: [2, 4] },
    { title: 'Public section', left: [1] }
  ], { ordinary: [1], wide: [] });
  arrangeIssueShowFields(reader.document);
  const readerSections = reader.document.querySelectorAll('.rfs-section');
  check(readerSections.length === 1 && readerSections[0].firstElementChild.textContent === 'Public section',
        'A section with no rendered fields stays absent although it is configured');
  check(readerSections[0].querySelectorAll('.attribute').length === 1 &&
        readerSections[0].querySelectorAll('.attribute')[0] === reader.fields[1] &&
        !reader.document.querySelectorAll('.cf_2').length && !reader.document.querySelectorAll('.cf_4').length,
        'Sections never create restricted ordinary or full-width fields from the layout');

  const wideOnly = issueFixture([{ title: 'Wide only', left: [3, 9] }], { ordinary: [], wide: [3] });
  [wideOnly.descriptionSeparator, wideOnly.description, wideOnly.attachmentsSeparator, wideOnly.attachments]
    .forEach(node => node.remove());
  arrangeIssueShowFields(wideOnly.document);
  const [wideContainer] = wideOnly.document.querySelectorAll('.rfs-show-sections');
  check(wideOnly.attributes.children[1] === wideContainer && !wideContainer.querySelectorAll('.splitcontent').length &&
        wideContainer.querySelectorAll('.attribute')[0] === wideOnly.fields[3] &&
        !wideOnly.document.querySelectorAll('.cf_9').length, 'Full-width-only ticket, omitted empty field and no columns');

  const failing = issueFixture([{ title: 'Mixed', left: [1, 3] }]);
  const before = snapshot(failing.document);
  const createElement = failing.document.createElement;
  let injected = false;
  failing.document.createElement = tag => {
    const target = createElement(tag);
    const appendChild = target.appendChild;
    target.appendChild = node => {
      if (node === failing.fields[3]) {
        check(failing.fields[1].parentNode !== failing.attributes.children[2].children[0], 'First move has happened');
        appendChild.call(target, node);
        injected = true;
        throw new Error('Injected move failure');
      }
      return appendChild.call(target, node);
    };
    return target;
  };
  arrangeIssueShowFields(failing.document);
  check(injected && snapshot(failing.document) === before, 'Failed move restores the original DOM');
  failing.document.createElement = createElement;
  arrangeIssueShowFields(failing.document);
  check(failing.document.querySelectorAll('.rfs-show-sections').length === 1, 'Retry after rollback succeeds');

  const filterFailure = issueFixture([{ title: 'Mixed', left: [1, 3] }]);
  const nativeBeforeFilter = snapshot(filterFailure.document);
  let filterErrorInjected = false;
  filterFailure.fields[3].afterClassToggle = () => {
    filterErrorInjected = true;
    throw new Error('Injected initial filter failure');
  };
  arrangeIssueShowFields(filterFailure.document);
  check(filterErrorInjected && snapshot(filterFailure.document) === nativeBeforeFilter &&
        !filterFailure.document.querySelectorAll('.rfs-show-filter').length,
        'Initial filter failure restores native positions and classes without a checkbox');

  for (const [name, prepare] of [
    ['missing anchor', fixture => fixture.end.remove()],
    ['empty layout', fixture => { fixture.start.dataset.sections = '[]'; }],
    ['malformed layout', fixture => { fixture.start.dataset.sections = '['; }],
    ['unexpected structure', fixture => { fixture.fields[1].parentNode.className = 'unexpected'; }],
    ['duplicate field ID', fixture => { fixture.fields[2].className = 'attribute cf_1'; }],
    ['no fields', fixture => { Object.values(fixture.fields).forEach(field => field.remove()); }]
  ]) {
    const fixture = issueFixture([{ title: 'Mixed', left: [1, 3] }]);
    prepare(fixture);
    const native = snapshot(fixture.document);
    arrangeIssueShowFields(fixture.document);
    check(snapshot(fixture.document) === native, `Native DOM preserved with ${name}`);
    check(!fixture.document.querySelectorAll('.rfs-show-filter').length, `No filter with ${name}`);
  }

  const filtered = issueFixture([
    { title: 'Mixed values', left: [1, 2, 3, 4, 5] },
    { title: 'Only empty values', left: [6, 7, 8, 9, 10] }
  ], { ordinary: [1, 2, 3, 4, 6, 7, 8, 9, 10], wide: [5] });
  const value = id => filtered.fields[id].querySelector(':scope > .value');
  value(2).textContent = 'Some text';
  value(3).textContent = '0';
  value(4).textContent = 'Non';
  value(5).firstElementChild.appendChild(filtered.document.createElement('img')).src = '/files/example.png';
  value(6).textContent = ' \n\u00a0\u200b';
  value(7).appendChild(filtered.document.createElement('p')).appendChild(filtered.document.createElement('br'));
  value(8).appendChild(filtered.document.createElement('img')).src = '';
  const hiddenImage = value(9).appendChild(filtered.document.createElement('img'));
  hiddenImage.src = '/files/hidden.png';
  hiddenImage.rendered = false;
  value(10).appendChild(filtered.document.createElement('svg')).appendChild(filtered.document.createElement('path')).d = '';

  arrangeIssueShowFields(filtered.document);
  const [filterControl] = filtered.document.querySelectorAll('.rfs-show-filter');
  const checkbox = filterControl.firstElementChild;
  const [mixedSection, emptySection] = filtered.document.querySelectorAll('.rfs-section');
  const isHidden = node => node.matches('.rfs-hidden-by-filter');
  check(checkbox.checked === true, 'Filter starts checked on consultation');

  function toggle(checkbox, checked) {
    checkbox.checked = checked;
    checkbox.dispatchEvent({ type: 'change' });
  }
  check([1, 6, 7, 8, 9, 10].every(id => isHidden(filtered.fields[id])), 'Empty values are hidden immediately');
  check([2, 3, 4, 5].every(id => !isHidden(filtered.fields[id])), 'Text, zero, No and image-only values stay visible');
  check(!isHidden(mixedSection) && isHidden(emptySection), 'Only sections with no value are hidden');
  const applied = snapshot(filtered.document);
  arrangeIssueShowFields(filtered.document);
  check(snapshot(filtered.document) === applied, 'A second arrangement leaves the filter state unchanged');
  const positions = Object.values(filtered.fields).map(node => [node, node.parentNode, node.parentNode.nodes.indexOf(node)]);
  toggle(checkbox, false);
  check(!filtered.document.querySelectorAll('.rfs-hidden-by-filter').length &&
        positions.every(([node, parent, index]) => parent.nodes[index] === node),
        'Unchecking restores the original nodes in place');
  const unfiltered = snapshot(filtered.document);
  toggle(checkbox, true);
  check(snapshot(filtered.document) === applied, 'Checking again restores the initial filtered state');
  toggle(checkbox, false);
  filtered.document.defaultView.dispatchEvent({ type: 'pageshow', persisted: false });
  check(snapshot(filtered.document) === unfiltered, 'An initial pageshow does not override an active consultation');
  filtered.document.defaultView.dispatchEvent({ type: 'pageshow', persisted: true });
  check(snapshot(filtered.document) === applied, 'Returning from the browser cache resets the filter to checked');

  const allEmpty = issueFixture([{ title: 'One', left: [1] }, { title: 'Two', left: [2] }], { wide: [] });
  arrangeIssueShowFields(allEmpty.document);
  const [allEmptyControl] = allEmpty.document.querySelectorAll('.rfs-show-filter');
  check(allEmptyControl.firstElementChild.checked && allEmpty.document.querySelectorAll('.rfs-section').every(isHidden) &&
        !isHidden(allEmptyControl) && !isHidden(allEmptyControl.parentNode),
        'The checked checkbox stays visible when all sections are hidden initially');
  toggle(allEmptyControl.firstElementChild, false);
  check(!allEmpty.document.querySelectorAll('.rfs-hidden-by-filter').length, 'Unchecking restores all sections immediately');
}

// Run with: node test/javascript/issue_show_layout_test.js
if (typeof module !== 'undefined' && require.main === module) {
  const { readFileSync } = require('node:fs');
  const { resolve } = require('node:path');
  const source = ['section_layout', 'issue_show_layout'].map(name =>
    readFileSync(resolve(__dirname, `../../app/views/redmine_form_sections/_${name}.js.erb`), 'utf8')
  ).join('\n');
  const arrangeIssueShowFields = new Function(`${source}\nreturn arrangeIssueShowFields;`)();
  testIssueShowLayout(arrangeIssueShowFields);
  console.log('Issue show layout tests passed');
}
