const hoursFromNow = (hours) => new Date(Date.now() + hours * 3600 * 1000).toISOString();

// Built once per test: the rendered expiry is compared against these exact
// timestamps, so they must not be recomputed between the stub and the assertion.
const buildVouchers = () => ({
  active: {
    guid: '11111111-1111-1111-1111-111111111111',
    status: 'created',
    input_voucher: '-----BEGIN OWNERSHIP VOUCHER-----\nQUJD\n-----END OWNERSHIP VOUCHER-----\n',
    output_voucher: null,
    output_guid: null,
    expiry: hoursFromNow(1),
  },
  expired: {
    guid: '22222222-2222-2222-2222-222222222222',
    status: 'created',
    input_voucher: null,
    output_voucher: null,
    output_guid: null,
    expiry: hoursFromNow(-1),
  },
  claimed: {
    guid: '33333333-3333-3333-3333-333333333333',
    status: 'claimed',
    input_voucher: null,
    output_voucher: null,
    output_guid: null,
    expiry: null,
  },
});

const voucherRow = (guid) => cy.contains('tbody tr', guid);

describe('FDO vouchers page tests', () => {
  context('no access before login', () => {
    it('redirects to login', function () {
      cy.visit('/fdo-vouchers');
      cy.location('pathname').should('eq', '/login');
    });
  });

  context('authenticated', () => {
    beforeEach(function () {
      const vouchers = buildVouchers();
      cy.wrap(vouchers).as('vouchers');

      cy.fixture('realm').then((realm) => {
        cy.intercept('GET', `/pairing/v1/${realm.name}/fdo/ownership_vouchers`, {
          body: { data: [vouchers.active, vouchers.expired, vouchers.claimed] },
        }).as('vouchersRequest');
        cy.login();
        cy.visit('/fdo-vouchers');
        cy.wait('@vouchersRequest');
      });
    });

    it('lists the rendezvous expiry of every voucher', function () {
      const { active } = this.vouchers;

      cy.get('h2').contains('FDO Ownership Vouchers');
      cy.get('thead th').eq(2).contains('Rendezvous expiry');

      voucherRow(active.guid).within(() => {
        cy.contains(new Date(active.expiry).toLocaleString());
        cy.contains('Expired').should('not.exist');
      });
    });

    it('flags a voucher whose registration is no longer served', function () {
      voucherRow(this.vouchers.expired.guid).contains('Expired');
    });

    it('shows no expiry for a voucher whose device completed Device Onboard', function () {
      voucherRow(this.vouchers.claimed.guid).within(() => {
        cy.get('td').eq(2).should('contain', '\u2014');
        cy.contains('Re-run TO0').should('not.exist');
      });
    });

    it('re-runs TO0 and reports the refreshed expiry', function () {
      const { expired } = this.vouchers;
      const refreshedExpiry = hoursFromNow(2);

      cy.fixture('realm').then((realm) => {
        cy.intercept(
          'POST',
          `/pairing/v1/${realm.name}/fdo/ownership_vouchers/${expired.guid}/to0`,
          { body: { data: { expiry: refreshedExpiry } } },
        ).as('runTo0');

        voucherRow(expired.guid).contains('Re-run TO0').click();
        cy.wait('@runTo0');

        cy.get('.alert-success').should(
          'contain',
          `The registration is now served until ${new Date(refreshedExpiry).toLocaleString()}`,
        );
      });
    });

    it('explains a TO0 rejected because Device Onboard already completed', function () {
      const { active } = this.vouchers;

      cy.fixture('realm').then((realm) => {
        cy.intercept(
          'POST',
          `/pairing/v1/${realm.name}/fdo/ownership_vouchers/${active.guid}/to0`,
          {
            statusCode: 409,
            body: {
              errors: { detail: 'Device Onboard has already completed for the voucher' },
            },
          },
        ).as('runTo0');

        voucherRow(active.guid).contains('Re-run TO0').click();
        cy.wait('@runTo0');

        cy.get('.alert-danger')
          .should('contain', 'Device Onboard has already completed')
          .and('contain', active.guid);
      });
    });
  });
});
