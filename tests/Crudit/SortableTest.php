<?php

namespace App\Tests\Crudit;

use App\Repository\UserRepository;
use Lle\CruditBundle\Test\TestSortableHelperTrait;
use Symfony\Bundle\FrameworkBundle\KernelBrowser;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

class SortableTest extends WebTestCase
{
    use TestSortableHelperTrait;

    protected KernelBrowser $client;

    protected function setUp(): void
    {
        $this->client = static::createClient();

        $userRepository = static::getContainer()->get(UserRepository::class);
        $this->client->loginUser($userRepository->findOneByEmail('dev@2le.net'));
    }
}
