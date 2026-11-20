'use strict';

// Minimal DOM fixture for exercising node moves and restoring their exact order.
class FixtureNode {
  constructor(tag, className = '') {
    this.tag = tag;
    this.className = className;
    this.dataset = {};
    this.nodes = [];
    this.parentNode = null;
  }

  get classList() { return this.className.split(' ').filter(Boolean); }
  get parentElement() { return this.parentNode; }
  get children() { return this.nodes.filter(node => node.tag !== '#comment'); }
  get firstElementChild() { return this.children[0]; }

  matches(selector) {
    if (selector.startsWith('#')) return this.id === selector.slice(1);
    if (selector.startsWith('.')) return selector.slice(1).split('.').every(name => this.classList.includes(name));
    return this.tag === selector;
  }

  querySelectorAll(selector) {
    const descendants = this.children.flatMap(child => [child, ...child.querySelectorAll('*')]);
    return selector === '*' ? descendants : descendants.filter(child => child.matches(selector));
  }

  querySelector(selector) {
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

  return { document, details, attributes, start, end, fields,
           descriptionSeparator, description, attachmentsSeparator, attachments, attachmentLink };
}

function testIssueShowLayout(arrangeIssueShowFields) {
  function check(condition, description) {
    if (!condition) throw new Error(description);
  }
  function snapshot(node) {
    return JSON.stringify([node.tag, node.id, node.className, node.textContent, node.dataset, node.nodes.map(snapshot)]);
  }

  const mixed = issueFixture([
    { title: '<b>Mixed</b>', left: [1, 3], right: [] },
    { title: 'Omitted', left: [5] }
  ]);
  const originalValue = mixed.fields[3].querySelector(':scope > .value');
  arrangeIssueShowFields(mixed.document);
  const [container] = mixed.document.querySelectorAll('.rfs-show-sections');
  check(mixed.attributes.children[1] === container, 'Sections replace the native ordinary block');
  const [section, other] = container.children;
  check(container.children.length === 2, 'Omitted fields create no section');
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
  }
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
