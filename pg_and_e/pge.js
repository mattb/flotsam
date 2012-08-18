var casper = require('casper').create();

casper.start('https://www.pge.com/myenergyweb/appmanager/pge/customer');

casper.then(function() {
  this.fill('form[name="login"]', {
    'USER': casper.cli.args[0],
    'PASSWORD': casper.cli.args[1]
  }, true);
});

casper.then(function() {
  this.click('li#primaryNav3 a');
});

casper.then(function() {
  casper.open('https://pge.opower.com/ei/app/myEnergyUse/usage/day/' + casper.cli.args[2] + '/' + casper.cli.args[3] + '/' + casper.cli.args[4]);
});

casper.then(function() {
  this.echo(JSON.stringify(casper.getGlobal('seriesDTO')));
});

casper.run();
