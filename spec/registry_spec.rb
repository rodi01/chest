require 'spec_helper'

describe Chest::Registry do
  before :all do
    api_endpoint = 'http://localhost:3000/api'
    token = 'test'
    @registry = Chest::Registry.new(token, api: api_endpoint)
  end

  it 'can publish package' do
    old_version = @registry.publish_package('spec/fixtures/Sketch-StickyGrid-0.1')
    expect(old_version).not_to have_key 'error'
    new_version = @registry.publish_package('spec/fixtures/Sketch-StickyGrid-1.0')
    expect(new_version).not_to have_key 'error'
  end

  it 'cannot publish old package' do
    status = @registry.publish_package('spec/fixtures/Sketch-StickyGrid-0.1')
    expect(status).to have_key 'error'
  end

  it 'cannot publish a package that have same version of latest package' do
    status = @registry.publish_package('spec/fixtures/Sketch-StickyGrid-1.0')
    expect(status).to have_key 'error'
  end

  it 'can fetch package information' do
    name = 'StickyGrid'
    info = @registry.fetch_package(name)

    expect(info).to be_a_kind_of Hash
    expect(info).to have_key 'name'
    expect(info['name']).to eq name
    expect(info['version']).to eq '1.0.0'
  end

  it 'can fetch versions index' do
    name = 'StickyGrid'
    info = @registry.fetch_package_versions(name)

    expect(info).to be_a_kind_of Hash
    expect(info).to have_key 'versions'
    expect(info['versions']).to be_a_kind_of Array
    expect(info['versions'].size).to eq 2
  end

  it 'can download package' do
    name = 'StickyGrid'
    Dir.mktmpdir do |tmpdir|
      @registry.download_package(name, 'latest', tmpdir)
      expect(File.exist?(File.join(tmpdir, 'chest.json'))).to eq(true)
      expect(JSON.parse(File.open(File.join(tmpdir, 'chest.json')).read)['version']).to eq('1.0.0')
    end
  end

  it 'can download old package' do
    name = 'StickyGrid'
    Dir.mktmpdir do |tmpdir|
      @registry.download_package(name, '0.1.0', tmpdir)
      expect(File.exist?(File.join(tmpdir, 'chest.json'))).to eq(true)
      expect(JSON.parse(File.open(File.join(tmpdir, 'chest.json')).read)['version']).to eq('0.1.0')
    end
  end

  it 'can unpublish plugin' do
    status = @registry.unpublish_package('StickyGrid')
    expect(status).to have_key 'status'
  end
end