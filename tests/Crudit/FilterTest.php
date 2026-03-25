<?php

namespace App\Tests\Crudit;

use App\Repository\UserRepository;
use Lle\CruditBundle\Test\FilterTestHelperTrait;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

class FilterTest extends WebTestCase
{
    use FilterTestHelperTrait;

    public const LOGIN_USER = 'dev@2le.net';

    public const USER_REPOSITORY = UserRepository::class;
}
